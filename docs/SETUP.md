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
5. **Before triggering the workflow**, read `docs/ORACLE-K3S-JOIN.md`. The
   live Oracle node is an independent single-node k3s cluster, but the
   Terraform cloud-init still runs the original k3s *agent* join, so it
   still needs `TAILSCALE_AUTH_KEY`, `K3S_URL`, and `K3S_TOKEN` repository
   secrets to render. On a rebuild, install k3s as a server afterwards
   instead of relying on that join (the doc has the command).
6. Trigger `.github/workflows/oracle-provision-retry.yml` manually once
   (Actions tab → Run workflow) to confirm the config is valid before
   leaving it on the 15-minute schedule. Expect it to fail with "Out of host
   capacity" the first several/many times — that's the retry loop working as
   designed, not a bug. It disables itself automatically once it succeeds.
   Once it does, confirm with `ssh oracle 'sudo -n kubectl get nodes -o wide'`
   that `pantry-bot-oracle` shows `Ready` as the only (control-plane) node.

## 3. GCP: not used for PantryBot

The GCP standby stack was removed when the failover design was retired.
PantryBot runs only on Oracle. The existing GCP e2-micro (`discordmusicbot`)
is the shared failover witness for opsbot, JMusicBot and Authentik. It is not
managed by this repo, so leave it alone.

## 4. After the Oracle node is up (done — kept here for a from-scratch rebuild)

This repo's job stops at "the node exists and runs a `Ready` k3s server of
its own." (Historical note: in the 2026-09 design, getting the bot to
benefit from a second node for cross-node failover required the PVC→emptyDir+Litestream
change, the cloudflared replica/anti-affinity change, and — the one that
actually caused an outage the first time — building the bot's image for
arm64 too. All three were done and proven, and the arm64 image requirement
still applies since PantryBot now runs only on the Oracle arm64 node; see `docs/DEPLOYMENT-PIPELINE-IMPACT.md`
and `docs/ARCHITECTURE.md` for the record.) If you're rebuilding this node
from scratch (`terraform destroy` + apply), those changes already live in
`k8s-homelab`/`pantry-bot` and don't need to be redone — the new node just
needs its own k3s server and to pull images that already support arm64.
PantryBot itself now runs only on this Oracle node; there is no failover
target elsewhere.

## 5. Ongoing: don't let this quietly start costing money

See `docs/ORACLE-BILLING-SAFETY.md` for the Always Free compliance check and
budget/notification setup — not a one-time setup step, something worth
re-checking periodically since Oracle has changed Always Free limits before
without much notice (see `ampere_ocpus`'s variable description).
