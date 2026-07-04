#!/usr/bin/env bash
# Pull GHCR builder images; build locally if pull fails outside CI.
#
# Usage (from node-pipeline/ with node repos in parent workspace):
#   PIPELINE_DIR=$PWD WORKSPACE=$PWD/.. ./scripts/ci-pull-builder-images.sh

set -euo pipefail

PIPELINE_DIR="${PIPELINE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WORKSPACE="${WORKSPACE:-$(dirname "$PIPELINE_DIR")}"

export DOCKERSHELF_BUILDER_IMAGE="${DOCKERSHELF_BUILDER_IMAGE:-ghcr.io/dockershelf/dockershelf-node-builder}"
export DOCKERSHELF_TOOLS_IMAGE="${DOCKERSHELF_TOOLS_IMAGE:-ghcr.io/dockershelf/dockershelf-node-builder/tools}"
SUITES="${DOCKERSHELF_SUITES-trixie unstable}"
ALLOW_LOCAL_FALLBACK="${DOCKERSHELF_ALLOW_LOCAL_BUILDER_FALLBACK:-}"

pull_or_build() {
    local image="$1"
    if docker pull "$image"; then
        echo "pulled $image"
        return 0
    fi
    echo "pull failed for $image" >&2
    return 1
}

build_local() {
    echo "falling back to local docker build from committed Dockerfiles"
    docker build -t "$DOCKERSHELF_TOOLS_IMAGE" \
        -f "$PIPELINE_DIR/dockerfiles/Dockerfile.tools" "$PIPELINE_DIR/dockerfiles"
    for s in $SUITES; do
        docker build -t "${DOCKERSHELF_BUILDER_IMAGE}/${s}" \
            -f "$PIPELINE_DIR/dockerfiles/Dockerfile.${s}" "$PIPELINE_DIR/dockerfiles"
    done
}

maybe_build_local() {
    if [[ -n "${GITHUB_ACTIONS:-}" && "$ALLOW_LOCAL_FALLBACK" != "1" ]]; then
        echo "builder image pull failed in CI; refusing local fallback" >&2
        echo "Fix GHCR package access or set DOCKERSHELF_ALLOW_LOCAL_BUILDER_FALLBACK=1 explicitly." >&2
        exit 1
    fi
    build_local
}

if pull_or_build "$DOCKERSHELF_TOOLS_IMAGE"; then
    for suite in $SUITES; do
        pull_or_build "${DOCKERSHELF_BUILDER_IMAGE}/${suite}" || {
            maybe_build_local
            exit 0
        }
    done
else
    maybe_build_local
fi
