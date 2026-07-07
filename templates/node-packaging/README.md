# node__NODE_MAJOR__

Debian packaging for Node.js __NODE_MAJOR__: monolithic `nodejs-__NODE_MAJOR__` packages used by the [Dockershelf node-pipeline](../node-pipeline).

## Supported Debian suites

- `trixie`
- `unstable`

Packaging trees live under `debiandirs/<suite>/`. Changelog tracks:

- **mainline** — `changelogs/mainline/<suite>`

## Build (from workspace)

Clone or seed this repo as a sibling of `node-pipeline/`, then from `node-pipeline/`:

```bash
make materialize NODE=__NODE_MAJOR__ DIST=trixie
make build NODE=__NODE_MAJOR__
```

See the [operations manual](https://github.com/Dockershelf/node-pipeline/blob/main/docs/operations.md) for new majors, version bumps, and new suites.

## Layout

| Path | Purpose |
|------|---------|
| `node/` | Upstream Node.js git submodule (`v__NODE_MAJOR__.x` branch) |
| `patches/` | Quilt series (usually empty for monolithic builds) |
| `debiandirs/` | Per-suite Debian packaging (`trixie`, `unstable`) |
| `changelogs/` | `mainline` dch history per suite |
