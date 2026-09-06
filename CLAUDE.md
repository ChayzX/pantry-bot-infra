# CLAUDE.md

Conventions for this repo. It holds the Terraform for Pantry Bot's cloud hosting —
not the bot's application code (that's `ChayzX/pantry-bot`).

## What lives here

- `terraform/oracle-primary/` — the Oracle Cloud Always-Free Ampere A1 (ARM) VM,
  joined to the existing home k3s cluster as an **agent node** over Tailscale.
  Not a standalone Docker host — see `docs/ARCHITECTURE.md`'s revision note
  and `docs/ORACLE-K3S-JOIN.md` before assuming otherwise.
- `terraform/gcp-standby/` — GCP Always-Free e2-micro VM stack. **Written but
  INACTIVE BY DESIGN — read `terraform/gcp-standby/STATUS.md` before touching
  this directory.** The active failover pair is home + Oracle only; GCP was
  deliberately dropped, not missed or half-finished. Still uses the older
  standalone-Docker design (`bot-host-init` module) — that hasn't been
  revisited since GCP is inactive.
- `.github/workflows/` — CI for `terraform fmt`/`validate`/`plan`, plus a scheduled
  workflow that retries provisioning the Oracle VM until OCI has capacity.
- `docs/` — architecture and setup notes, including
  `docs/ORACLE-K3S-JOIN.md` (home-side k3s/Tailscale prep, required before
  Oracle can join) and `docs/DEPLOYMENT-PIPELINE-IMPACT.md` (how this
  interacts with `k8s-homelab`'s real, merge-gated `kubectl apply` deploy
  pipeline — not Watchtower, despite what `pantry-bot`'s own CLAUDE.md/PLAN.md
  say; those describe an earlier design than what's actually deployed).

## Conventions

- Terraform state lives remotely in Cloudflare R2 (S3-compatible backend) — never
  commit `.tfstate` or `.terraform/` to git.
- Never commit real credentials, `.tfvars` with secrets, or private keys. All
  account-specific values (OCI tenancy/user OCIDs, API keys, GCP project ID, R2
  credentials, Tailscale auth keys, k3s tokens) are GitHub Actions secrets or
  passed via `-backend-config`/`-var-file` at apply time, never hardcoded in
  `.tf` files.
- Run `terraform fmt -recursive` before committing.
- Each stack (`oracle-primary`, `gcp-standby`) is applied independently — don't
  merge them into one root module. They fail, scale, and get destroyed on
  different schedules (Oracle capacity retries; GCP is a one-time apply).
- The Oracle VM is treated as **disposable at the node level**: cloud-init
  only installs Tailscale and joins k3s. Anything the bot needs (data,
  config) lives either in the cluster (Secrets/ConfigMaps/Litestream-to-R2)
  or gets scheduled onto it as a pod — never assume the node's local disk
  holds anything precious. If you find yourself treating it as precious,
  something has drifted from the intended design — fix that instead of
  working around it.
- Don't hand-manage a VM that Terraform is supposed to own. If a GCP box already
  exists from before this repo existed, `terraform import` it rather than creating
  a duplicate — Always Free eligibility is per billing account, and a second
  e2-micro will likely just start incurring cost.
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
- Do not run `terraform apply` (or the `gcp-standby-apply.yml` workflow)
  against `gcp-standby` without the user explicitly asking for GCP to rejoin
  the active failover set — it's off on purpose, see its `STATUS.md`. If a
  box already exists there outside Terraform's state, import first regardless.
- Do not remove the OCI-capacity retry workflow's soft-fail handling for expected
  "Out of host capacity" errors — that's intentional, not a bug (see
  `docs/DEPLOYMENT-PIPELINE-IMPACT.md`).
