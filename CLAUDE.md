# CLAUDE.md

Conventions for this repo. It holds the Terraform for Pantry Bot's cloud hosting —
not the bot's application code (that's `ChayzX/pantry-bot`).

## What lives here

Current state: PantryBot runs ONLY on the Oracle Cloud node (single-site since 2026-09-25). There is no home-cluster, Canada or GCP PantryBot runtime, standby, witness or failover. Observability for it is self-hosted Grafana/Prometheus/Loki (namespace `observability` on minecraftmachine); Grafana Cloud is no longer used.


- `terraform/oracle-primary/`: the Oracle Cloud Always-Free Ampere A1 (ARM) VM.
  The live node is an **independent single-node k3s cluster** (`k3s server`,
  control-plane). It does not join the home cluster. The Terraform's
  `k3s-agent-init` cloud-init still describes the original agent join; read
  `docs/ORACLE-K3S-JOIN.md` before touching it. Editing that template changes
  `user_data` and plans a replacement of the live VM.
- The GCP standby stack and the standalone-Docker `bot-host-init` module were
  removed when the failover design was retired. There is no GCP stack here.
- `.github/workflows/` — CI for `terraform fmt`/`validate`/`plan`, plus a scheduled
  workflow that retried provisioning the Oracle VM until OCI had capacity
  (disabled now that the node exists).
- `docs/` — architecture and setup notes, including
  `docs/ORACLE-K3S-JOIN.md` (Oracle is an independent k3s cluster; history
  and rebuild notes) and `docs/DEPLOYMENT-PIPELINE-IMPACT.md` (how this
  interacts with `k8s-homelab`'s real, merge-gated `kubectl apply` deploy
  pipeline — not Watchtower, despite what `pantry-bot`'s own CLAUDE.md/PLAN.md
  say; those describe an earlier design than what's actually deployed).

## Conventions

- Terraform state lives remotely in Cloudflare R2 (S3-compatible backend) — never
  commit `.tfstate` or `.terraform/` to git.
- Never commit real credentials, `.tfvars` with secrets, or private keys. All
  account-specific values (OCI tenancy/user OCIDs, API keys, R2
  credentials, Tailscale auth keys, k3s tokens) are GitHub Actions secrets or
  passed via `-backend-config`/`-var-file` at apply time, never hardcoded in
  `.tf` files.
- Run `terraform fmt -recursive` before committing.
- Keep each stack its own root module; don't merge future stacks into
  `oracle-primary`.
- The Oracle VM is treated as **disposable at the node level**: cloud-init
  only installs Tailscale (and, as written, the original k3s agent join; the
  live node runs its own k3s server). Anything the bot needs (data,
  config) lives either in the cluster (Secrets/ConfigMaps/Litestream-to-R2)
  or gets scheduled onto it as a pod — never assume the node's local disk
  holds anything precious. If you find yourself treating it as precious,
  something has drifted from the intended design — fix that instead of
  working around it.
- Don't hand-manage a VM that Terraform is supposed to own.
- The GCP e2-micro `discordmusicbot` (project `dave-487602`) is the shared
  failover witness for the opsbot, JMusicBot and Authentik standby designs. It
  was never PantryBot hosting and is not managed here. Do not delete it.
- Changes to the bot's actual Kubernetes manifests (PVC, Deployment,
  cloudflared) live in `chayzx/k8s-homelab`, not here — that's a live
  production cluster repo with its own conservative git-push conventions
  (see its CLAUDE.md). Don't push there without explicit confirmation, even
  if a broader plan involving this repo was already approved.

## GitHub Issues + Projects

Same as `chayzx/pantry-bot`: work is tracked as GitHub Issues in this repo (or in
`pantry-bot` for cross-cutting infra work), not TodoWrite/markdown TODOs. Use the
`gh` CLI / GitHub tools, assign yourself before starting, link commits with
`closes #N`.

## Do not

- Do not commit secrets, ever, even temporarily "to test something."
- Do not run `terraform apply` against `oracle-primary` without reviewing the
  plan for an instance replacement (see `docs/ORACLE-K3S-JOIN.md`).
- Do not remove the OCI-capacity retry workflow's soft-fail handling for expected
  "Out of host capacity" errors — that's intentional, not a bug (see
  `docs/DEPLOYMENT-PIPELINE-IMPACT.md`).
