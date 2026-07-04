#!/usr/bin/env bash
# Install portable CPython interpreters for Node.js configure (build-time only).
#
# Node majors need specific Python versions that are not always packaged in
# Debian trixie/sid. These live under /opt/dockershelf/python and are not part of
# the runtime nodejs .deb.

set -euo pipefail

RELEASE_TAG="${DOCKERSHELF_PYTHON_STANDALONE_RELEASE:-20251010}"
BASE_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${RELEASE_TAG}"
TARGET="${DOCKERSHELF_PYTHON_PREFIX:-/opt/dockershelf/python}"
ARCH="x86_64-unknown-linux-gnu"

declare -A PYTHON_VERSIONS=(
    [3.9]=3.9.24
    [3.10]=3.10.19
    [3.11]=3.11.14
    [3.12]=3.12.12
    [3.13]=3.13.8
)

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends \
    ca-certificates \
    wget \
    >/dev/null

mkdir -p "${TARGET}/versions" "${TARGET}/bin"

for minor in "${!PYTHON_VERSIONS[@]}"; do
    full="${PYTHON_VERSIONS[$minor]}"
    archive="cpython-${full}+${RELEASE_TAG}-${ARCH}-install_only_stripped.tar.gz"
    url="${BASE_URL}/${archive}"
  tmp="$(mktemp -d)"
    echo "Installing Python ${full} from ${archive}"
    wget -q -O "${tmp}/${archive}" "${url}"
    rm -rf "${TARGET}/versions/${minor}"
    mkdir -p "${TARGET}/versions/${minor}"
    tar -xzf "${tmp}/${archive}" -C "${TARGET}/versions/${minor}" --strip-components=1
    rm -rf "${tmp}"
    interpreter="${TARGET}/versions/${minor}/bin/python${minor}"
    if [[ ! -x "${interpreter}" ]]; then
        echo "missing interpreter after extract: ${interpreter}" >&2
        exit 1
    fi
    ln -sf "../versions/${minor}/bin/python${minor}" "${TARGET}/bin/python${minor}"
done

apt-get purge -y wget >/dev/null || true
apt-get autoremove -y >/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/*

for minor in 3.9 3.10 3.11 3.12 3.13; do
    "${TARGET}/bin/python${minor}" --version
done
