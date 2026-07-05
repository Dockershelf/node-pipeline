# Operations manual

How to add a new Node.js major line, bump an existing Node version, or add a new Debian suite to the Dockershelf Node packaging pipeline.

**Workspace:** run commands from `node-pipeline/` unless noted. Each `nodeXX/` repo is a sibling in the parent directory (`dockershelf-pipeline/`).

**Version string format:** Debian package versions look like `22.11.0-1+trixie3`:

| Part | Meaning |
|------|---------|
| `22.11.0` | Upstream Node.js version |
| `-1` | Debian packaging revision |
| `+trixie3` | Suite-specific rebuild counter |

---

## Prerequisites

```bash
cd node-pipeline
cp config.env.example config.env
make bootstrap
make build-tools-image
```

Ensure `DEBFULLNAME` and `DEBEMAIL` are set in `config.env` (or your git config).

---

## 1. Add a new Node major line (e.g. node26)

### 1.1 Create the packaging repository

1. Create `Dockershelf/node26` on GitHub (empty repo), or seed locally:

   ```bash
   cd node-pipeline
   ./scripts/seed-node-repo.sh 26 ../node26
   ```

2. Alternatively fork the closest existing line:

   ```bash
   cd ..
   git clone https://github.com/Dockershelf/node24.git node26
   cd node26
   git remote set-url origin https://github.com/Dockershelf/node26.git
   ```

3. Point the `node` submodule at `v26.x` and refresh packaging metadata.

### 1.2 Register the repo in node-pipeline

Edit [`Makefile`](../Makefile) — add `26` to `NODE_VERSIONS`:

```makefile
NODE_VERSIONS := 16 18 20 22 24 26
```

### 1.3 Build and publish

```bash
make materialize NODE=26 DIST=trixie
make build NODE=26
make publish DIST=trixie
```

Repeat for `unstable` as needed.

### 1.4 Downstream (Dockershelf images)

After packages are in your APT repo, update the main `dockershelf` repo:

- Shelf lists / `scripts/discover_shelf_versions.py`
- `node/build-image.sh` apt source and version pins

---

## 2. Bump Node patch version

```bash
cd ../node22
git submodule update --init node
../node-pipeline/meta-gbp update
```

Then from `node-pipeline/`:

```bash
make materialize NODE=22 DIST=trixie
make build NODE=22
make publish DIST=trixie
```

### Packaging-only rebuild (same upstream version)

```bash
cd ../node22
../node-pipeline/meta-gbp changelog --only trixie -m 'Rebuild for trixie: adjust control deps'
git add changelogs && git commit -m 'changelog: trixie rebuild'
```

---

## 3. Add a new Debian suite

For each `nodeXX` you support:

1. Copy `debiandirs/trixie` to `debiandirs/<codename>` and adjust `Build-Depends`.
2. Add `changelogs/mainline/<codename>` and `changelogs/nightly/<codename>`.
3. Update `DOCKERSHELF_SUITES` in `config.env`.
4. Run `make generate-dockerfiles && make build-builder-images`.
5. Extend droplet `conf/distributions` with the new codename stanza.

---

## Quick reference

| Goal | Where | Key command |
|------|--------|-------------|
| New `nodeXX` repo | GitHub or seed script | `./scripts/seed-node-repo.sh XX ../nodeXX` |
| Register major | `node-pipeline/Makefile` | Add to `NODE_VERSIONS` |
| New upstream patch | `nodeXX/` | `meta-gbp update` |
| Materialize | `node-pipeline/` | `make materialize NODE=22 DIST=trixie` |
| Binary build | `node-pipeline/` | `make build NODE=22` |
| Publish to APT | `node-pipeline/` | `make publish DIST=trixie` |

---

## Troubleshooting

**`make materialize` fails validation** — `changelogs/mainline` and `changelogs/nightly` must list the same suite names; each needs `debiandirs/<suite>/`.

**Build fails on `mk-build-deps`** — regenerate builder images: `make generate-dockerfiles && make build-builder-images`.

**`make publish` finds no `.deb` files** — artifacts land in `node-pipeline/dist/` after `make build`.
