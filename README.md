# Dockershelf Node packaging pipeline

Orchestration for building Node.js into monolithic Debian replacement packages (`nodejs`) and publishing to the self-hosted APT repository on DigitalOcean.

Mirrors [python-pipeline](../python-pipeline/) for Debian (`trixie`, `unstable`) and Dockershelf hosting.

## Workspace layout

Clone this repo as a sibling of the `node*` packaging repos:

```text
dockershelf-pipeline/
├── node-pipeline/     # this repo
├── node16/
├── node18/
├── node20/
├── node22/
└── node24/
```

## Quick start

```bash
cd node-pipeline
cp config.env.example config.env
make bootstrap
make build-tools-image
make build-builder-images
make materialize NODE=22 DIST=trixie
make build NODE=22
make publish DIST=trixie
```

## Build a single distribution

```bash
make materialize NODE=22 DIST=trixie
make build NODE=22
```

Output `.deb` files land in `dist/`.

## Generate builder Dockerfiles

```bash
make generate-dockerfiles
make build-builder-images
```

Builder images are tagged `ghcr.io/dockershelf/dockershelf-node-builder/<suite>` (e.g. `.../trixie`).

## Configuration

Copy `config.env.example` to `config.env`. See `docs/deploy-setup.md` for droplet APT hosting (shared with Python packages).

## Continuous integration

GitHub Actions mirror [python-pipeline](../python-pipeline/docs/ci.md):

- Builder images on GHCR (`dockershelf-node-builder/*`)
- Reusable `update-meta-gbp.yml` (update → build → smoke → publish)
- Each `nodeXX` repo calls the reusable workflow on a staggered daily schedule

See [docs/ci.md](docs/ci.md) and [docs/deploy-setup.md](docs/deploy-setup.md).

## Source repositories

| Local path (sibling) | Remote |
|----------------------|--------|
| `../node16/` … `../node24/` | `https://github.com/Dockershelf/nodeXX` |

`make bootstrap` clones any missing `node*` repos from GitHub, or seeds them from `templates/node-packaging/` when remotes are unavailable.

## Operations manual

Step-by-step guides for maintainers:

- [Adding a new Node major line (node26)](docs/operations.md#1-add-a-new-node-major-line-eg-node26)
- [Bumping Node patch version](docs/operations.md#2-bump-node-patch-version)
- [Adding a new Debian suite](docs/operations.md#3-add-a-new-debian-suite)

Full reference: [docs/operations.md](docs/operations.md)
