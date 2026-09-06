# How this interacts with the existing deploy pipeline

**Revision note**: this doc originally described a Docker Compose +
Watchtower interaction model. That was based on `pantry-bot`'s own
CLAUDE.md/PLAN.md, which turned out to describe an earlier design than
what's actually deployed. The real, currently-live pipeline (found in
`chayzx/k8s-homelab`) is a merge-gated `kubectl apply` + `rollout restart`
workflow — Watchtower and its predecessor Keel were both explicitly retired
there. This doc now reflects that real pipeline.

## The actual pipeline (from `k8s-homelab/DEPLOYING.md`)

1. Push to `main` in `pantry-bot` → GitHub Actions builds and publishes
   `ghcr.io/chayzx/pantry-bot:latest` automatically.
2. A human clicks "Run workflow" on `deploy.yml`, which reaches the cluster
   through a dedicated Cloudflare Tunnel + Access route and runs
   `kubectl set image` + `rollout restart` + `rollout status`, with
   `rollout undo` on failure. Deliberately manual-click, not automatic —
   see that repo's history for why (a prior automatic system's silent
   credential failure went unnoticed for a full day).

**This repo (`pantry-bot-infra`) does not touch this pipeline at all.** It
provisions a *node* for the cluster to schedule pods onto. It has no
involvement in how the bot's code gets built, published, or rolled out —
that's 100% `pantry-bot` + `k8s-homelab`'s existing, working system.

## What this repo's automation actually does

- **Oracle Terraform + the retry workflow**: creates the VM and joins it to
  the cluster as a k3s agent node (see `docs/ORACLE-K3S-JOIN.md`). That's
  the entire scope. Once the node is `Ready`, it's just cluster capacity —
  the existing `deploy.yml` pipeline doesn't know or care which node a pod
  lands on.
- **Cloud-init on the Oracle node** installs Tailscale and joins k3s. It does
  **not** install Docker Compose, Watchtower, or run the bot directly — all
  of that is superseded by "it's now a k8s node, k8s schedules pods onto it."

## What still needs to change, and where (not in this repo)

For the bot to actually benefit from having two nodes (rather than just
having spare capacity sitting there), two changes are needed in
`k8s-homelab`, tracked separately:

1. **`pantry-bot/30-pvc.yaml` + `40-deployment.yaml`**: replace the
   `local-path` PVC (pins the pod to the home node) with an `emptyDir` plus
   a Litestream restore-on-start init step, so the Deployment can actually
   be rescheduled onto Oracle if home goes down. Until this lands, having a
   second node doesn't add failover for the bot specifically — the pod
   simply can't move.
2. **`pantry-bot/60-deployment-cloudflared.yaml`**: bump `cloudflared` to 2
   replicas with pod anti-affinity, so one lands on each node. This one's
   lower-risk (cloudflared is stateless) and gives HTTP-surface redundancy
   immediately once both nodes exist.

## One thing to watch for with cloud-init specifically

cloud-init only runs once, at first boot. A future change to what gets
installed on the Oracle node (e.g., a different Tailscale flag, a k3s agent
config change) only takes effect on a **new** instance — not on one that's
already joined. To push such a change to an existing node, either apply it
by hand over SSH, or force recreation (`terraform taint`, or bump
`node_name`) to get a fresh cloud-init run.
