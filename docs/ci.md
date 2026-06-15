# GitHub Actions CI

Continuous integration for Dockershelf Node.js packaging: builder images on GHCR, scheduled
`meta-gbp update` / build / smoke test / APT publish across `node16`–`node24`.

## Workflows

| Workflow | Repo | Purpose |
|----------|------|---------|
| [`builder-images.yml`](../.github/workflows/builder-images.yml) | `node-pipeline` | Build and push `ghcr.io/dockershelf/dockershelf-node-builder/*` |
| [`update-meta-gbp.yml`](../.github/workflows/update-meta-gbp.yml) | `node-pipeline` | Reusable: update → build → smoke → publish |
| [`pr.yml`](../.github/workflows/pr.yml) | `node-pipeline` | `pre-commit` on pull requests |
| [`publish.yml`](../.github/workflows/publish.yml) | `node-pipeline` | Manual republish of local `dist/` to APT |
| [`deploy-connectivity.yml`](../.github/workflows/deploy-connectivity.yml) | `node-pipeline` | Manual SSH/incoming-dir check (no rsync) |
| [`main.yml`](https://github.com/Dockershelf/node22/blob/main/.github/workflows/main.yml) | each `nodeXX` | Daily schedule + dispatch → calls reusable workflow |

## CI workspace layout

```text
$GITHUB_WORKSPACE/
├── node22/              # triggering node repo
└── node-pipeline/       # orchestration checkout
```

Scripts:

- [`scripts/ci-setup-workspace.sh`](../scripts/ci-setup-workspace.sh) — submodule init, export GHCR image names
- [`scripts/ci-pull-builder-images.sh`](../scripts/ci-pull-builder-images.sh) — pull GHCR images or build locally
- [`scripts/debian-smoke-test.sh`](../scripts/debian-smoke-test.sh) — install `.deb`s in `debian:{suite}-slim`
- [`scripts/ci-publish.sh`](../scripts/ci-publish.sh) — rsync + `import-incoming.sh`
- [`scripts/ci-deploy-preflight.sh`](../scripts/ci-deploy-preflight.sh) — validate `DEPLOY_*` vars (optional `--connectivity`)

## GHCR images

| Image | Tag |
|-------|-----|
| `ghcr.io/dockershelf/dockershelf-node-builder/tools` | `latest`, `sha-<commit>` |
| `ghcr.io/dockershelf/dockershelf-node-builder/trixie` | `latest`, `sha-<commit>` |
| `ghcr.io/dockershelf/dockershelf-node-builder/unstable` | `latest`, `sha-<commit>` |

`builder-images.yml` pushes on push to `main`; pull requests build only (no push).

Node builder images use a **separate** GHCR prefix from Python (`dockershelf-builder`) so both pipelines can coexist.

## Secrets and variables

Configure on **`Dockershelf/node-pipeline`** and each **`nodeXX`** repo (or at org level).

Run [`scripts/ci-check-config.sh`](../scripts/ci-check-config.sh) to list which secrets/variables are set (values are never printed). Use `--strict` to fail when deploy configuration is incomplete.

Full droplet + GitHub wiring: [`docs/deploy-setup.md`](deploy-setup.md).

### Secrets

| Name | Purpose |
|------|---------|
| `DEPLOY_SSH_KEY` | Private SSH key for `DEPLOY_USER@DEPLOY_HOST` (shared with Python pipeline) |
| `GH_PACKAGES_TOKEN` | Optional; defaults to `GITHUB_TOKEN` with `packages: write` on `node-pipeline` |

### Repository variables

| Name | Example |
|------|---------|
| `DEPLOY_HOST` | `apt.luisalejandro.org` |
| `DEPLOY_USER` | `deploy` |
| `DEPLOY_DIR` | `/var/www/debian` |
| `DEPLOY_INCOMING` | `/var/www/debian/incoming` |
| `DEBFULLNAME` | `Dockershelf Maintainer` |
| `DEBEMAIL` | `maintainer@example.com` |

Publish jobs run only when `publish` input is true **and** `DEPLOY_HOST` is set. When deploy variables are missing, build and smoke still run and the workflow summary notes that publish was skipped.

## GitHub settings

1. **`node-pipeline` → Settings → Actions → General**
   - Workflow permissions: read and write (for GHCR push).
   - Allow reuse of workflows by repos in the `Dockershelf` org.

2. **Each `nodeXX` repo**
   - Actions → access to `node-pipeline` reusable workflows.
   - Caller workflow needs `permissions: contents: write` so `meta-gbp update` commits can push.
   - Same secrets/variables as above (or inherit org-level).

3. **GHCR package visibility**
   - Link each `dockershelf-node-builder/*` package to `node16` … `node24` under **Package settings → Manage Actions access**, or make packages **public**.
   - Caller workflows use `permissions: packages: read`.
   - If `docker pull` is denied, CI builds from committed `dockerfiles/Dockerfile.*`.

## Schedule (UTC)

Cron is staggered after the Python window (`9:45`–`10:05` UTC):

| Repo | Cron |
|------|------|
| node16 | `10 10 * * *` |
| node18 | `15 10 * * *` |
| node20 | `20 10 * * *` |
| node22 | `25 10 * * *` |
| node24 | `30 10 * * *` |

Scheduled runs publish when deploy variables and `DEPLOY_SSH_KEY` are configured. Use `workflow_dispatch` with `publish: false` to build and smoke-test only.

## Manual runs

**Full pipeline (node22):** Actions → packaging → Run workflow.

**Republish existing debs:** `node-pipeline` → Actions → publish → choose suite (expects `dist/*.deb` in the runner workspace).

**Deploy connectivity only:** `node-pipeline` → Actions → Deploy connectivity.

## Failure modes

| Failure | Action |
|---------|--------|
| `meta-gbp update` rebase conflict | Resolve locally, push fix, re-run workflow |
| Builder image pull fails | CI falls back to local docker build from committed `dockerfiles/` (slow) |
| Smoke test `apt-get -f install` fails | Check missing runtime deps in generated `.deb` set |
| Publish SSH/rsync fails | Verify `DEPLOY_*` variables and `DEPLOY_SSH_KEY`; run **Deploy connectivity** workflow |
| Build timeout | Node V8 compile can exceed default limits; `update-meta-gbp.yml` uses `timeout-minutes: 360` |

## Verification checklist

After pushing `node-pipeline` to GitHub:

1. `./scripts/ci-check-config.sh --strict` (local, with `gh` authenticated)
2. Run **Deploy connectivity** workflow
3. Run **Builder images** workflow
4. Push `main.yml` to `node22`, dispatch with `publish: false`, then `publish: true`
5. Confirm `curl -I https://apt.luisalejandro.org/dockershelf/dists/trixie/Release` lists nodejs packages
