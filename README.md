# lac-SUT — NAT-hidden PaaS container → lac-controlled hole-punch test node

A Debian image that turns a free-tier PaaS container (Render/Scaleway/HF/Back4app/Northflank/
CNB/ModelScope) into a **controllable system-under-test** for NAT-traversal work. It replaces
the chisel relay (one free container per platform) and, unlike chisel, works through Alibaba
EAS too.

## What it runs (`lac-entry.sh`, supervised)
- **`lac relay`** — gateway on the ingress port: `/ws` → tunnel, everything else → a health
  server (keeps the PaaS edge probe green).
- **`lac tunnel <ROOM> --shell-server`** — a co-located peer offering **Shell + FileShare
  (`lac cp`) + Socks5 + HttpProxy + `-L`/`-R`** into the container.

From a laptop: `lac tunnel <ROOM> --relay wss://<ingress>/ws [--relay-token/-H auth]` → a shell
+ `lac cp` to push binaries + `--socks5`/`-L` into the container's network. No external relay.

## Toolset (for hole-punch testing + verification)
`tcpdump` (pcap the punch UDP), `ip`/`ss` + `conntrack` (NAT mapping/table), `netcat`/`socat`
(UDP/TCP endpoints), `iperf3` (throughput), `dig`/`ping`/`traceroute`, `sshd` (ssh-over-punch).

## Build / deploy
- Binary `lac` in the context is the platform (x86_64) build; the Apple-container local build
  stages the aarch64 one (`build.sh arm64|amd64`).
- Local China build: `container build --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn -t lac-sut .`
- PaaS build: default `deb.debian.org`. Env: `ROOM` (unique per container), `PORT` (ingress),
  `SSHD=1`+`SSH_PUBKEY` to enable sshd.

Deploy recipe per platform: `nat_traversal/docs_nodes/guide-lac-sut.md`.
