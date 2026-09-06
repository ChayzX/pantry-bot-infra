# pantry-bot-infra

Terraform + CI for Pantry Bot's cloud hosting.

- **`terraform/oracle-primary/`** — Oracle Cloud Always-Free Ampere A1 (ARM)
  VM, meant to become the bot's permanent primary host. Capacity for this
  shape is contested, so `.github/workflows/oracle-provision-retry.yml`
  retries provisioning on a schedule until OCI has room, then disables
  itself.
- **`terraform/gcp-standby/`** — GCP Always-Free e2-micro VM, the failover
  standby.
- **`terraform/modules/bot-host-init/`** — shared cloud-init used by both
  stacks: Docker, `cloudflared` (joins the existing Cloudflare Tunnel as a
  replica), Watchtower (existing GHCR auto-deploy pipeline), and Litestream.
  Does **not** start the bot itself — see
  [`docs/DEPLOYMENT-PIPELINE-IMPACT.md`](docs/DEPLOYMENT-PIPELINE-IMPACT.md)
  for why.

This repo provisions hosts. The actual bot application, its backup strategy
(Litestream → R2), and its failover/leader-election logic live in
[`chayzx/pantry-bot`](https://github.com/ChayzX/pantry-bot) — start with
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the two repos fit
together.

## Getting started

See [`docs/SETUP.md`](docs/SETUP.md) for the one-time account setup
(R2 backend, OCI credentials, GCP credentials) required before any workflow
here can run.
