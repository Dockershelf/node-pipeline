#!/usr/bin/env bash
# Install built .deb packages in a Debian suite container and run smoke tests.
#
# Usage (local debs):
#   ./scripts/debian-smoke-test.sh --dist trixie --node 22 --dist-dir ../node-pipeline/dist --arch amd64
# Usage (from public APT repo):
#   ./scripts/debian-smoke-test.sh --from-apt --dist unstable --node 22

set -euo pipefail

DIST=""
NODE=""
DIST_DIR=""
FROM_APT=0
APT_URL="${DOCKERSHELF_APT_URL:-https://apt.dockershelf.com/dockershelf}"
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
        --from-apt)
            FROM_APT=1
            shift
            ;;
        --apt-url)
            APT_URL="$2"
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

if [[ -z "$DIST" || -z "$NODE" ]]; then
    echo "usage: $0 --dist trixie --node 22 [--dist-dir path/to/debs | --from-apt] [--arch amd64]" >&2
    exit 1
fi

if [[ "$FROM_APT" -eq 0 && -z "$DIST_DIR" ]]; then
    echo "either --dist-dir or --from-apt is required" >&2
    exit 1
fi

IMAGE="debian:${DIST}-slim"
CONTAINER="dockershelf-node-smoke-$$"
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CONTAINER" --platform "linux/${ARCH}" "$IMAGE" sleep 3600

if [[ "$FROM_APT" -eq 1 ]]; then
    docker exec "$CONTAINER" bash -euxc "
        apt-get update -qq
        apt-get install -y -qq ca-certificates gnupg curl
        curl -fsSL ${APT_URL}/dockershelf-apt-signing.pub | gpg --dearmor > /usr/share/keyrings/dockershelf.gpg
        echo 'deb [signed-by=/usr/share/keyrings/dockershelf.gpg] ${APT_URL} ${DIST} main' > /etc/apt/sources.list.d/dockershelf.list
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "nodejs-${NODE}"
        node --version
        npm --version
        test -x /usr/bin/node
        if [ -e /usr/bin/nodejs ]; then nodejs --version; else ln -sf node /usr/bin/nodejs; fi
    "
    echo "smoke test passed for node${NODE} on ${DIST}/${ARCH} (from ${APT_URL})"
    exit 0
fi

DIST_DIR="$(cd "$DIST_DIR" && pwd)"
shopt -s nullglob
debs=("$DIST_DIR"/*.deb)
if [[ ${#debs[@]} -eq 0 ]]; then
    echo "no .deb files in $DIST_DIR" >&2
    exit 1
fi

docker exec "$CONTAINER" mkdir -p /debs
docker cp "$DIST_DIR/." "$CONTAINER:/debs/"

docker exec "$CONTAINER" bash -euxc "
    apt-get update -qq
    apt-get install -y -qq dpkg-dev
    shopt -s nullglob
    pkgs=(/debs/*.deb)
    if [[ \${#pkgs[@]} -eq 0 ]]; then
        echo 'no .deb files in /debs' >&2
        exit 1
    fi
    (cd /debs && dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz)
    echo 'deb [trusted=yes] file:/debs ./' > /etc/apt/sources.list.d/dockershelf-debs.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "nodejs-${NODE}"
    node --version
    npm --version
    test -x /usr/bin/node
    if [ -e /usr/bin/nodejs ]; then nodejs --version; else ln -sf node /usr/bin/nodejs; fi
"

echo "smoke test passed for node${NODE} on ${DIST}/${ARCH}"
