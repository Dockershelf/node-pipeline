#!/usr/bin/env bash
# Seed a local node{major} packaging repository from the node-pipeline template.
#
# Usage:
#   ./seed-node-repo.sh 22 /path/to/deadsnakes-pipeline/node22
#
# The upstream `node/` submodule is not cloned here (too large for bootstrap).
# Initialize it later with ../init-node-submodules.sh or let meta-gbp fetch tarballs.

set -euo pipefail

MAJOR="${1:?usage: seed-node-repo.sh <major> <target-dir>}"
TARGET="${2:?usage: seed-node-repo.sh <major> <target-dir>}"
PIPELINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${PIPELINE}/templates/node-packaging"
PYTHON_MINOR="$((MAJOR / 2 + 1))"

if [ -e "${TARGET}" ]; then
    echo "ERROR: ${TARGET} already exists"
    exit 1
fi

cp -a "${TEMPLATE}" "${TARGET}"

while IFS= read -r -d '' file; do
    if grep -q '__NODE_MAJOR__\|__PYTHON_MINOR__' "${file}" 2>/dev/null; then
        perl -pi -e "s/__NODE_MAJOR__/${MAJOR}/g; s/__PYTHON_MINOR__/${PYTHON_MINOR}/g" "${file}"
    fi
done < <(find "${TARGET}" -type f -print0)

cd "${TARGET}"
git init -b main
mkdir -p node
cat > .gitmodules <<EOF
[submodule "node"]
	path = node
	url = https://github.com/nodejs/node.git
	branch = v${MAJOR}.x
EOF
cat > node/.gitkeep <<'EOF'
# Populated by init-node-submodules.sh or: git submodule update --init node
EOF
git add -A
git commit -m "Initial node${MAJOR} Debian packaging repository"

echo "Seeded ${TARGET} (run init-node-submodules.sh to fetch upstream node)"
