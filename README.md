# pantry-bot-infra

Terraform + CI for Pantry Bot's cloud hosting.

**Status: live.** The Oracle node is provisioned and is where PantryBot runs.
PantryBot runs ONLY on the Oracle Cloud node (single-site since 2026-09-25). There is no home-cluster, Canada or GCP PantryBot runtime, standby, witness or failover. Observability for it is self-hosted Grafana/Prometheus/Loki (namespace `observability` on minecraftmachine); Grafana Cloud is no longer used.

- **`terraform/oracle-primary/`**: the Oracle Cloud Always-Free Ampere A1
  (ARM) VM. The live node, `pantry-bot-oracle`, is an **independent
  single-node k3s cluster** (its own `k3s server`/control-plane). It does not
  join the home cluster. See [`docs/ORACLE-K3S-JOIN.md`](docs/ORACLE-K3S-JOIN.md)
  for the current state and for how the Terraform drifted from it. Capacity
  for this shape is contested, so `.github/workflows/oracle-provision-retry.yml`
  retried provisioning until OCI had room (now disabled).
- **`terraform/modules/k3s-agent-init/`**: cloud-init used by
  `oracle-primary`. It installs Tailscale and then runs the k3s *agent*
  installer, which reflects the original 2026-09-06 provisioning, not the live
  node. Do not edit it casually: it feeds the instance's `user_data`, so any
  change plans a replacement of the live VM. See `docs/ORACLE-K3S-JOIN.md`.

The GCP standby stack (`terraform/gcp-standby/`) and its `bot-host-init`
module were removed once the failover design was retired. PantryBot has no
GCP runtime, standby or failover.

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
for the Oracle k3s layout (independent single-node cluster) and rebuild
notes.
