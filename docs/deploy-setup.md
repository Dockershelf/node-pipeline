# APT deploy setup (Node pipeline)

Node packages publish to the **same** DigitalOcean APT droplet and repository tree as Python packages.
Org-level `DEPLOY_*` variables and `DEPLOY_SSH_KEY` configured for [python-pipeline](../python-pipeline/docs/deploy-setup.md) apply here without duplication.

Public repository URL: **`https://apt.dockershelf.com/dockershelf/`**

## Architecture

```text
nodeXX workflow  →  update-meta-gbp.yml  →  build  →  smoke  →  publish
                                                                    │
                                                                    ├─ rsync → /var/www/debian/incoming/
                                                                    └─ SSH  → import-incoming.sh → reprepro
                                                                                    │
                                                                              nginx /dockershelf/
```

## What is shared with Python

| Item | Notes |
|------|-------|
| Droplet host | `apt.dockershelf.com` |
| Repository root | `/var/www/debian` |
| Incoming directory | `/var/www/debian/incoming` |
| Nginx path | `/dockershelf/` → `/var/www/debian/` |
| `DEPLOY_SSH_KEY` | Org secret |
| `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_DIR`, `DEPLOY_INCOMING` | Org variables |

Node and Python packages share `trixie` and `unstable` codenames in the same `reprepro` configuration.

## Bootstrap and TLS

Do **not** run a second droplet bootstrap for Node. Follow the Python pipeline guide:

- [python-pipeline/docs/deploy-setup.md](https://github.com/Dockershelf/python-pipeline/blob/main/docs/deploy-setup.md) — DNS, TLS, GitHub secrets/variables
- [python-pipeline/debian-repo-setup/bootstrap-droplet.sh](https://github.com/Dockershelf/python-pipeline/blob/main/debian-repo-setup/bootstrap-droplet.sh)
- [python-pipeline/debian-repo-setup/create-ci-deploy-key.sh](https://github.com/Dockershelf/python-pipeline/blob/main/debian-repo-setup/create-ci-deploy-key.sh)

## Node-specific GitHub setup

| Secret / variable | Node-specific? |
|-----------------|----------------|
| `DEPLOY_*` | No — reuse org-level from Python setup |

Run `./scripts/ci-check-config.sh --strict` from `node-pipeline/` to verify configuration.

## Client apt line (Dockershelf images)

```text
deb [signed-by=/usr/share/keyrings/dockershelf.gpg] https://apt.dockershelf.com/dockershelf trixie main
```

Use codename matching the image base (`trixie` or `unstable` for sid).

Fetch the signing public key from the droplet (see python deploy-setup) or set `DOCKERSHELF_APT_GPG_KEY_ID` when building downstream images with [`node/build-image.sh`](../../../node/build-image.sh).

## Verify publish

```bash
curl -I https://apt.dockershelf.com/dockershelf/dists/trixie/Release
curl -s https://apt.dockershelf.com/dockershelf/dists/trixie/main/binary-amd64/Packages.gz | zcat | grep -i nodejs
```

## Further reading

- [docs/ci.md](ci.md) — workflow inventory and schedules
- [debian-repo-setup/README.md](../debian-repo-setup/README.md) — import script and layout
