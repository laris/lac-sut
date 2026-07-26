# lac-SUT — a NAT-hidden PaaS container turned into a controllable p2p hole-punch TEST NODE.
# Runs a lac relay (gateway on the ingress port) + a co-located `lac tunnel --shell-server`
# peer, so LOCAL dials the container's own /ws and gets a shell + `lac cp` file transfer +
# --socks5 + -L/-R into this container. Replaces the chisel relay (one free container/platform).
#
# Ships the networking toolkit for hole-punch testing + verification:
#   tcpdump (pcap the punch UDP), iproute2/ss + conntrack (NAT mapping/table), netcat/socat
#   (UDP/TCP test endpoints), iperf3 (throughput), dig/ping/traceroute, sshd (ssh-over-punch).
# Build per-arch: place the matching `lac` binary (aarch64 for local Apple container, x86_64
# for the PaaS platforms) as ./lac in the build context.
FROM debian:stable-slim
ENV DEBIAN_FRONTEND=noninteractive
# APT_MIRROR: keep deb.debian.org for the PaaS (overseas) builds; override to a CN mirror
# (e.g. mirrors.tuna.tsinghua.edu.cn) for the local China build so apt isn't glacially slow.
ARG APT_MIRROR=deb.debian.org
RUN set -eux; \
    if [ "$APT_MIRROR" != "deb.debian.org" ]; then \
      for f in /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list; do \
        [ -f "$f" ] && sed -i "s|deb.debian.org|$APT_MIRROR|g; s|security.debian.org|$APT_MIRROR|g" "$f" || true; \
      done; \
    fi; \
    apt-get update && apt-get install -y --no-install-recommends \
      openssh-server openssh-client ca-certificates curl python3 \
      iproute2 iputils-ping dnsutils tcpdump netcat-openbsd socat traceroute \
      procps net-tools iperf3 conntrack; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /run/sshd /app/www; printf ok > /app/www/health; printf ok > /app/www/index.html; \
    ssh-keygen -A; \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/; s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
COPY lac /usr/local/bin/lac
COPY lac-entry.sh /entrypoint.sh
RUN chmod 0755 /usr/local/bin/lac /entrypoint.sh && /usr/local/bin/lac --version
WORKDIR /app
EXPOSE 7860
CMD ["/entrypoint.sh"]
