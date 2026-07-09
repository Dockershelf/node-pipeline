#!/usr/bin/env bash
# Seed a local node{major} packaging repository from the node-pipeline template.
#
# Usage:
#   ./seed-node-repo.sh 22 /path/to/dockershelf-pipeline/node22
#
# The upstream `node/` submodule gitlink is registered pointing to the
# v{MAJOR}.x branch HEAD, but the working tree is not cloned here (too large
# for bootstrap). Initialize it later with ../init-node-submodules.sh or:
#   git submodule update --init node

set -euo pipefail

MAJOR="${1:?usage: seed-node-repo.sh <major> <target-dir>}"
TARGET="${2:?usage: seed-node-repo.sh <major> <target-dir>}"
PIPELINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${PIPELINE}/templates/node-packaging"
PYTHON_MINOR="$((MAJOR / 2 + 1))"

# Stagger Node.js builds: Thursdays, every 2 hours with modulo 24 wrapping
# Ensures no collisions with 5-version limit and auto-wraps past midnight
CRON_HOUR=$(( (((MAJOR - 18) / 2) * 2 + 2) % 24 ))
packaging_cron() {
    printf '0 %d * * 4' "$CRON_HOUR"
}

if [ -e "${TARGET}" ]; then
    echo "ERROR: ${TARGET} already exists"
    exit 1
fi

cp -a "${TEMPLATE}" "${TARGET}"

while IFS= read -r -d '' file; do
    if grep -qE '__NODE_MAJOR__|__PYTHON_MINOR__|__PACKAGING_CRON__' "${file}" 2>/dev/null; then
        perl -pi -e "s/__NODE_MAJOR__/${MAJOR}/g; s/__PYTHON_MINOR__/${PYTHON_MINOR}/g; s/__PACKAGING_CRON__/$(packaging_cron | sed 's/[\/&]/\\&/g')/g" "${file}"
    fi
done < <(find "${TARGET}" -type f -print0)

cd "${TARGET}"
git init -b main
chmod +x debiandirs/*/rules

# Register node/ as a proper 160000 gitlink pointing to the v${MAJOR}.x
# branch HEAD, matching the python-pipeline cpython/ submodule pattern.
# The working tree is populated later by init-node-submodules.sh or:
#   git submodule update --init node
NODE_SHA="$(curl -fsSL "https://api.github.com/repos/nodejs/node/branches/v${MAJOR}.x" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['commit']['sha'])")"
rm -rf node
git update-index --add --cacheinfo 160000 "${NODE_SHA}" node
git add .gitmodules
git commit -m "Initial node${MAJOR} Debian packaging repository"

echo "Seeded ${TARGET} (run init-node-submodules.sh to fetch upstream node)"
