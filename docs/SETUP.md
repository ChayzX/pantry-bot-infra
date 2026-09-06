# Setup

Everything Terraform-shaped is in this repo, but a handful of one-time,
account-specific steps have to happen outside git (API keys, bucket
creation) before any workflow here can run. This is the checklist.

## 1. Terraform state backend (Cloudflare R2)

Reuses the R2 account already planned for Litestream backups — one bucket,
two purposes.

1. Create (or reuse) an R2 bucket, e.g. `pantry-bot-backups`.
2. Create an R2 API token with read/write access to that bucket.
3. Add these as **repository secrets** in `pantry-bot-infra` (Settings →
   Secrets and variables → Actions):
   - `TF_STATE_R2_BUCKET`
   - `TF_STATE_R2_ENDPOINT` (e.g. `https://<account-id>.r2.cloudflarestorage.com`)
   - `TF_STATE_R2_ACCESS_KEY_ID`
   - `TF_STATE_R2_SECRET_ACCESS_KEY`

## 2. Oracle Cloud (primary)

1. Sign up for an OCI Always Free account if you haven't already (this is
   the account you previously couldn't get A1 capacity on — no need to
   re-signup, same account works, the retry workflow is what's new).
2. Create an API signing key pair for your OCI user (Profile → API Keys →
   Add API Key). Note the fingerprint OCI shows you.
3. Gather: tenancy OCID, user OCID, the fingerprint, the private key PEM,
   your home region, and a compartment OCID (root compartment's OCID works
   fine for a single-project tenancy).
4. Add as repository secrets:
   - `OCI_TENANCY_OCID`, `OCI_USER_OCID`, `OCI_FINGERPRINT`, `OCI_REGION`,
     `OCI_COMPARTMENT_OCID`
   - `OCI_PRIVATE_KEY` — paste the full PEM including
     `-----BEGIN PRIVATE KEY-----` / `-----END-----` lines
   - `PANTRY_BOT_SSH_PUBLIC_KEY` — a public key you'll use to SSH into the box
5. **Before triggering the workflow**, complete the home-side k3s/Tailscale
   prep in `docs/ORACLE-K3S-JOIN.md` — this node joins your existing k3s
   cluster as an agent, it isn't a standalone Docker host, so it needs
   `TAILSCALE_AUTH_KEY`, `K3S_URL`, and `K3S_TOKEN` as repository secrets
   (that doc explains where each one comes from) before it can join
   successfully.
6. Trigger `.github/workflows/oracle-provision-retry.yml` manually once
   (Actions tab → Run workflow) to confirm the config is valid before
   leaving it on the 15-minute schedule. Expect it to fail with "Out of host
   capacity" the first several/many times — that's the retry loop working as
   designed, not a bug. It disables itself automatically once it succeeds.
   Once it does, confirm with `kubectl get nodes -o wide` from the home
   server that the new node shows `Ready`.

## 3. GCP (standby) — INACTIVE BY DESIGN, skip this unless told otherwise

**Status: intentionally not part of the active failover set.** GCP was
dropped in favor of a plain home + Oracle pair once Oracle became the target
primary — see `terraform/gcp-standby/STATUS.md` and
`docs/ARCHITECTURE.md`. This section is left here for if/when that decision
changes, not because setup is incomplete. Do not work through these steps
proactively; confirm with the user first.

If you already have a GCP e2-micro box running manually from earlier
planning, **do not run a plain apply** — you'll create a duplicate that
starts costing money. Import the existing instance into Terraform state
first:

```bash
cd terraform/gcp-standby
terraform init -backend-config=... # same R2 backend config as above
terraform import google_compute_instance.standby \
  projects/<your-project-id>/zones/<zone>/instances/<instance-name>
terraform plan   # review carefully — should show no destructive changes
```

If you don't have one yet, add these repository secrets and run
`.github/workflows/gcp-standby-apply.yml` manually:

- `GCP_PROJECT_ID`
- `GCP_CREDENTIALS_JSON` — a service account key JSON with Compute Admin on
  that project (paste the whole JSON file contents)
- `PANTRY_BOT_SSH_PUBLIC_KEY_GCP` — format `username:ssh-rsa AAAA...`
- Reuses `CLOUDFLARE_TUNNEL_TOKEN`, `LITESTREAM_R2_ACCESS_KEY_ID`,
  `LITESTREAM_R2_SECRET_ACCESS_KEY` from step 2.

## 4. After the Oracle node joins

This repo's job stops at "the node exists and is a `Ready` member of the k3s
cluster." Getting the bot to actually benefit from a second node (real
failover, not just spare capacity) requires the PVC→emptyDir+Litestream
change and the cloudflared replica/anti-affinity change, both tracked as
`k8s-homelab` PRs — see `docs/DEPLOYMENT-PIPELINE-IMPACT.md`. Nothing
further to do in *this* repo until you want to resize, recreate, or add
another node.
