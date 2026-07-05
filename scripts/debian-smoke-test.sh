#!/usr/bin/env bash
# Install built .deb packages in a Debian suite container and run smoke tests.
#
# Usage:
#   ./scripts/debian-smoke-test.sh --dist trixie --node 22 --dist-dir ../node-pipeline/dist --arch amd64

set -euo pipefail

DIST=""
NODE=""
DIST_DIR=""
ARCH="${DOCKERSHELF_ARCH:-amd64}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dist)
            DIST="$2"
            shift 2
            ;;
        --node)
            NODE="$2"
            shift 2
            ;;
        --dist-dir)
            DIST_DIR="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$DIST" || -z "$NODE" || -z "$DIST_DIR" ]]; then
    echo "usage: $0 --dist trixie --node 22 --dist-dir path/to/debs [--arch amd64]" >&2
    exit 1
fi

DIST_DIR="$(cd "$DIST_DIR" && pwd)"
shopt -s nullglob
debs=("$DIST_DIR"/*.deb)
if [[ ${#debs[@]} -eq 0 ]]; then
    echo "no .deb files in $DIST_DIR" >&2
    exit 1
fi

IMAGE="debian:${DIST}-slim"
CONTAINER="dockershelf-node-smoke-$$"
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CONTAINER" --platform "linux/${ARCH}" "$IMAGE" sleep 3600
docker exec "$CONTAINER" mkdir -p /debs
docker cp "$DIST_DIR/." "$CONTAINER:/debs/"

docker exec "$CONTAINER" bash -euxc "
    apt-get update -qq
    shopt -s nullglob
    pkgs=(/debs/*.deb)
    dpkg -i \"\${pkgs[@]}\" || true
    DEBIAN_FRONTEND=noninteractive apt-get -f install -y -qq
    node --version
    npm --version
    test -x /usr/bin/node
    if [ -e /usr/bin/nodejs ]; then nodejs --version; else ln -sf node /usr/bin/nodejs; fi
"

echo "smoke test passed for node${NODE} on ${DIST}/${ARCH}"
