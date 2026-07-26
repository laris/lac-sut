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

# 1. health backend so the PaaS/EAS edge probe on / and /health stays HTTP 200.
sup health python3 -m http.server 7861 --bind 127.0.0.1 --directory /app/www &
sleep 1
# 2. relay/gateway on the ingress: /ws -> internal tunnel; everything else -> health backend.
sup relay lac relay --listen 0.0.0.0:"$PORT" --fallback 127.0.0.1:7861 --tunnel-path /ws &
sleep 3
# 3. in-container peer: PTY shell-server + FileShare(cp) + Socks5 + -L/-R exit into this box.
sup peer lac tunnel "$ROOM" --relay ws://127.0.0.1:"$PORT"/ws --shell-server --stable-peer-id &
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
