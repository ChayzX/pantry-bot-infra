# CLAUDE.md

Conventions for this repo. It holds the Terraform for Pantry Bot's cloud hosting —
not the bot's application code (that's `ChayzX/pantry-bot`).

## What lives here

- `terraform/oracle-primary/` — the Oracle Cloud Always-Free Ampere A1 (ARM) VM that
  is meant to become the bot's primary host.
- `terraform/gcp-standby/` — the GCP Always-Free e2-micro VM that runs as the
  failover standby (see `chayzx/pantry-bot`'s leader-election design).
- `.github/workflows/` — CI for `terraform fmt`/`validate`/`plan`, plus a scheduled
  workflow that retries provisioning the Oracle VM until OCI has capacity.
- `docs/` — architecture and setup notes, including how this interacts with
  `pantry-bot`'s existing GHCR/Watchtower deploy pipeline.

## Conventions

- Terraform state lives remotely in Cloudflare R2 (S3-compatible backend) — never
  commit `.tfstate` or `.terraform/` to git.
- Never commit real credentials, `.tfvars` with secrets, or private keys. All
  account-specific values (OCI tenancy/user OCIDs, API keys, GCP project ID, R2
  credentials) are GitHub Actions secrets or passed via `-backend-config`/
  `-var-file` at apply time, never hardcoded in `.tf` files.
- Run `terraform fmt -recursive` before committing.
- Each stack (`oracle-primary`, `gcp-standby`) is applied independently — don't
  merge them into one root module. They fail, scale, and get destroyed on
  different schedules (Oracle capacity retries; GCP is a one-time apply).
- Both VMs are treated as **disposable**: cloud-init bootstraps Docker, Watchtower,
  and `cloudflared` only. The bot's actual data lives in Litestream's replica in
  R2, not on either VM's disk — so `terraform destroy` + `apply` should always be
  safe to run. If you find yourself treating either VM's local disk as precious,
  something has drifted from the intended design — fix that instead of working
  around it.
- Don't hand-manage a VM that Terraform is supposed to own. If a GCP box already
  exists from before this repo existed, `terraform import` it rather than creating
  a duplicate — Always Free eligibility is per billing account, and a second
  e2-micro will likely just start incurring cost.

## GitHub Issues + Projects

Same as `chayzx/pantry-bot`: work is tracked as GitHub Issues in this repo (or in
`pantry-bot` for cross-cutting infra work), not TodoWrite/markdown TODOs. Use the
`gh` CLI / GitHub tools, assign yourself before starting, link commits with
`closes #N`.

## Do not

- Do not commit secrets, ever, even temporarily "to test something."
- Do not run `terraform apply` against `gcp-standby` if a box already exists there
  outside Terraform's state — import first.
- Do not remove the OCI-capacity retry workflow's soft-fail handling for expected
  "Out of host capacity" errors — that's intentional, not a bug (see
  `docs/DEPLOYMENT-PIPELINE-IMPACT.md`).
