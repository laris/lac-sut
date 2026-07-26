#!/usr/bin/env bash
# Stage the matching lac binary into this build context, then (optionally) build the image.
#   build.sh arm64            -> stage aarch64 lac (for the local Apple `container`, linux/arm64)
#   build.sh amd64            -> stage x86_64 lac  (for the PaaS platforms, linux/amd64)
#   build.sh arm64 --local    -> also `container build -t lac-sut .` in the Apple container
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; LACREPO="$HOME/dev/codes/lacuna"
ARCH="${1:?usage: build.sh arm64|amd64 [--local]}"
case "$ARCH" in
  arm64) SRC="$LACREPO/target/aarch64-unknown-linux-musl/release/lac" ;;
  amd64) SRC="$LACREPO/target/x86_64-unknown-linux-musl/release/lac" ;;
  *) echo "arch must be arm64|amd64"; exit 2 ;;
esac
[ -x "$SRC" ] || { echo "missing $SRC — build lac first (cargo zigbuild -p lacuna-cli --target …)"; exit 1; }
cp "$SRC" "$HERE/lac"
echo "staged lac ($ARCH, $(du -h "$SRC" | cut -f1)) into $HERE/lac"
if [ "${2:-}" = "--local" ]; then
  ( cd "$HERE" && container build -t lac-sut . )
fi
