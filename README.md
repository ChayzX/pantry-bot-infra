# pantry-bot-infra

Terraform + CI for Pantry Bot's cloud hosting.

**Status: live.** The Oracle node is provisioned, joined, and has passed a
real cross-node failover test (see `docs/ARCHITECTURE.md`). Not a
plan-in-progress.

- **`terraform/oracle-primary/`** — Oracle Cloud Always-Free Ampere A1 (ARM)
  VM, joined to the existing home k3s cluster as an **agent node** over
  Tailscale (not a standalone Docker host — see revision note in
  [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)). Capacity for this shape is
  contested, so `.github/workflows/oracle-provision-retry.yml` retries
  provisioning on a schedule until OCI has room, then disables itself. See
  [`docs/ORACLE-K3S-JOIN.md`](docs/ORACLE-K3S-JOIN.md) for the home-side
  prerequisites this depends on.
- **`terraform/gcp-standby/`** — GCP Always-Free e2-micro VM. **Status:
  inactive by design, not deployed** — see
  [`terraform/gcp-standby/STATUS.md`](terraform/gcp-standby/STATUS.md) before
  assuming this was missed or is in progress. The active failover pair is
  home + Oracle.
- **`terraform/modules/k3s-agent-init/`** — cloud-init used by
  `oracle-primary`: installs Tailscale, joins the tailnet, then joins the
  home k3s cluster as an agent. Does not install Docker Compose or start the
  bot directly — the bot is a pod, scheduled by k8s.
- **`terraform/modules/bot-host-init/`** — the older standalone-Docker
  cloud-init (Docker, `cloudflared`, Watchtower, Litestream). No longer used
  by `oracle-primary`; kept only because `gcp-standby` still references it
  and that stack's design hasn't been revisited (it's inactive anyway — see
  above).

This repo provisions hosts. The actual bot application and its backup
strategy (Litestream → R2) live in
[`chayzx/pantry-bot`](https://github.com/ChayzX/pantry-bot); its Kubernetes
manifests and deploy pipeline live in
[`chayzx/k8s-homelab`](https://github.com/ChayzX/k8s-homelab) — start with
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the three repos fit
together.

## Getting started

See [`docs/SETUP.md`](docs/SETUP.md) for the one-time account setup (R2
backend, OCI credentials) and [`docs/ORACLE-K3S-JOIN.md`](docs/ORACLE-K3S-JOIN.md)
for the home-side k3s/Tailscale prep required before the Oracle node can
join the cluster.
