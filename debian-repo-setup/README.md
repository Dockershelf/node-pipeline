# APT repository setup (Node pipeline)

Node packages publish to the **same** DigitalOcean APT droplet and repository
tree as Python and Go packages — no separate droplet or bootstrap is required.

This directory holds pipeline-local copies of the shared `reprepro` config
(`reprepro-distributions`), the SSH import hook (`import-incoming.sh`), and the
nginx site config (`nginx-debian.conf`) used by the publish flow.

## Canonical setup

Droplet bootstrap, signing key, DNS/TLS, and GitHub secrets/variables are
documented once in the Python pipeline:

- [python-pipeline/debian-repo-setup/README.md](https://github.com/Dockershelf/python-pipeline/blob/main/debian-repo-setup/README.md) — droplet layout, bootstrap, client apt line
- [python-pipeline/docs/deploy-setup.md](https://github.com/Dockershelf/python-pipeline/blob/main/docs/deploy-setup.md) — end-to-end deploy checklist
- [../docs/deploy-setup.md](../docs/deploy-setup.md) — Node-specific notes (shared variables, no re-bootstrap)

## Publish flow

From `node-pipeline/` after `make build`:

```bash
make publish DIST=trixie
```

This rsyncs `dist/*.deb` to the droplet and runs `import-incoming.sh` over SSH.
CI uses the same path via [`scripts/ci-publish.sh`](../scripts/ci-publish.sh).
