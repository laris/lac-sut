#!/bin/sh
# lac-SUT entrypoint: a self-healing lac control plane on a PaaS container.
#   relay (gateway on the ingress) + in-container --shell-server peer, each supervised.
# One deploy → dial in from LOCAL for shell + `lac cp` + --socks5 + -L/-R; never redeploy
# (push new binaries via `lac cp`, run anything via the shell). Optional sshd for ssh tests.
# Env: ROOM (unique per container, default lac-sut) · PORT (ingress, default 7860) ·
#      SSHD=1 to start sshd · SSH_PUBKEY=<key> · SSHD_PORT (default 2222).
ROOM="${ROOM:-lac-sut}"
PORT="${PORT:-7860}"
export RUST_LOG="${RUST_LOG:-lacuna_relay=info,lacuna_tunnel=info,info}"
export LACUNA_TUNNEL_OPEN_OK_TIMEOUT_SECS="${LACUNA_TUNNEL_OPEN_OK_TIMEOUT_SECS:-30}"
echo "=== lac-SUT (debian): room=$ROOM ingress-port=$PORT ==="

sup() { n="$1"; shift; while :; do echo "[sup] start $n"; "$@"; echo "[sup] $n exit=$?; restart 2s"; sleep 2; done; }

# Age-capped supervisor for the shell-server peer. The relay can EVICT the peer on a keepalive
# (FRAME_PONG) timeout, after which it sits ALIVE-BUT-DROPPED (studio-log 2026-07-31: repeated
# "control request timeout" heartbeats → "no FRAME_PONG in 355s, closing tunnel" → slots=0, and it does
# NOT self-reconnect until a client pokes it). The plain exit-based `sup` never catches that (the process
# never exits). Fix: cap the peer's age WELL UNDER the eviction window so a fresh, re-registered peer is
# always in the room — mechanism-independent (it doesn't matter WHY it dropped). --stable-peer-id makes
# each refresh reclaim its own slot; detached punch jobs (setsid) + short fleetctl commands survive the
# ~2 s re-register gap. Tune via PEER_MAX_AGE (default 180 s, safely under the ~355 s eviction seen live).
peer_sup() {
  while :; do
    echo "[sup] start peer (age-cap ${PEER_MAX_AGE:-180}s)"
    lac tunnel "$ROOM" --relay ws://127.0.0.1:"$PORT"/ws --shell-server --stable-peer-id &
    pid=$!
    ( sleep "${PEER_MAX_AGE:-180}"; kill "$pid" 2>/dev/null ) &
    ager=$!
    wait "$pid" 2>/dev/null
    kill "$ager" 2>/dev/null
    echo "[sup] peer refresh (age-cap or exit); restart 2s"
    sleep 2
  done
}

# 1. health backend so the PaaS/EAS edge probe on / and /health stays HTTP 200.
sup health python3 -m http.server 7861 --bind 127.0.0.1 --directory /app/www &
sleep 1
# 2. relay/gateway on the ingress: /ws -> internal tunnel; everything else -> health backend.
sup relay lac relay --listen 0.0.0.0:"$PORT" --fallback 127.0.0.1:7861 --tunnel-path /ws &
sleep 3
# 3. in-container peer (PTY shell-server + FileShare(cp) + Socks5 + -L/-R): age-capped watchdog
#    (see peer_sup) so a relay keepalive-eviction can't leave it alive-but-dropped.
peer_sup &
# 4. optional sshd for ssh-over-punch tests (enable with SSHD=1; inject SSH_PUBKEY).
if [ -n "${SSHD:-}" ]; then
  if [ -n "${SSH_PUBKEY:-}" ]; then
    mkdir -p /root/.ssh && printf '%s\n' "$SSH_PUBKEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys
  fi
  sup sshd /usr/sbin/sshd -D -e -p "${SSHD_PORT:-2222}" &
fi

echo "=== supervised: health + relay + peer${SSHD:+ + sshd} ; room=$ROOM ==="
wait
