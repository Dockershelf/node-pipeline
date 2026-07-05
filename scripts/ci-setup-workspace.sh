#!/usr/bin/env bash
# Prepare CI workspace: init node submodule and export image env vars.
#
# Usage:
#   NODE_REPO_DIR=/path/to/node22 PIPELINE_DIR=/path/to/node-pipeline \
#     ./scripts/ci-setup-workspace.sh
#
# Or pass positional args: ./ci-setup-workspace.sh /path/to/node22 [/path/to/node-pipeline]

set -euo pipefail

NODE_REPO_DIR="${NODE_REPO_DIR:-${1:-}}"
PIPELINE_DIR="${PIPELINE_DIR:-${2:-}}"

if [[ -z "$NODE_REPO_DIR" ]]; then
    echo "NODE_REPO_DIR required (env or first argument)" >&2
    exit 1
fi

NODE_REPO_DIR="$(cd "$NODE_REPO_DIR" && pwd)"
PIPELINE_DIR="${PIPELINE_DIR:-$(dirname "$NODE_REPO_DIR")/node-pipeline}"
PIPELINE_DIR="$(cd "$PIPELINE_DIR" && pwd)"

for f in meta-gbp build docker-run tools; do
    if [[ ! -e "$PIPELINE_DIR/$f" ]]; then
        echo "missing $PIPELINE_DIR/$f" >&2
        exit 1
    fi
done

if [[ -f "$NODE_REPO_DIR/.gitmodules" ]]; then
    git -C "$NODE_REPO_DIR" submodule update --init node || true
    if [[ -d "$NODE_REPO_DIR/node/.git" ]]; then
        git -C "$NODE_REPO_DIR/node" fetch --tags origin || true
    fi
fi

export NODE_REPO_DIR
export PIPELINE_DIR
export DOCKERSHELF_ARCH="${DOCKERSHELF_ARCH:-amd64}"
export DOCKERSHELF_BUILDER_IMAGE="${DOCKERSHELF_BUILDER_IMAGE:-ghcr.io/dockershelf/dockershelf-node-builder}"
export DOCKERSHELF_TOOLS_IMAGE="${DOCKERSHELF_TOOLS_IMAGE:-ghcr.io/dockershelf/dockershelf-node-builder/tools}"

if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
        echo "NODE_REPO_DIR=$NODE_REPO_DIR"
        echo "PIPELINE_DIR=$PIPELINE_DIR"
        echo "DOCKERSHELF_ARCH=$DOCKERSHELF_ARCH"
        echo "DOCKERSHELF_BUILDER_IMAGE=$DOCKERSHELF_BUILDER_IMAGE"
        echo "DOCKERSHELF_TOOLS_IMAGE=$DOCKERSHELF_TOOLS_IMAGE"
    } >>"$GITHUB_ENV"
fi

echo "NODE_REPO_DIR=$NODE_REPO_DIR"
echo "PIPELINE_DIR=$PIPELINE_DIR"
echo "DOCKERSHELF_ARCH=$DOCKERSHELF_ARCH"
echo "DOCKERSHELF_BUILDER_IMAGE=$DOCKERSHELF_BUILDER_IMAGE"
echo "DOCKERSHELF_TOOLS_IMAGE=$DOCKERSHELF_TOOLS_IMAGE"
