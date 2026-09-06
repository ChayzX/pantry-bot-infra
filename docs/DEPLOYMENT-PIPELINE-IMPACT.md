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

## What changed elsewhere to make the second node actually useful (done, not pending)

Three changes landed outside this repo, none of which this repo's own
pipeline needed to know about:

1. **`k8s-homelab`, `pantry-bot/30-pvc.yaml` → `40-deployment.yaml`**: the
   `local-path` PVC (pinned the pod to the home node) was replaced with an
   `emptyDir` plus a Litestream restore-on-start init step. Proven with a
   real failover test, not just deployed — see `k8s-homelab#177`'s closing
   comment.
2. **`k8s-homelab`, `pantry-bot/60-deployment-cloudflared.yaml`**: bumped to
   2 replicas with pod anti-affinity, one per node. Also proven — the
   previously-Pending replica scheduled and served traffic the moment Oracle
   existed.
3. **`pantry-bot`'s own `deploy.yml`**: the build step now produces
   multi-arch images (`linux/amd64,linux/arm64`), with a CI check that fails
   loudly if a platform is ever missing again. This one wasn't optional —
   the first real deploy after Oracle joined caused a full outage without
   it. See `pantry-bot#127` (the incident) and `#128` (the fix). Full
   writeup in `docs/ARCHITECTURE.md`'s "images must be multi-arch" section.

## One thing to watch for with cloud-init specifically

cloud-init only runs once, at first boot. A future change to what gets
installed on the Oracle node (e.g., a different Tailscale flag, a k3s agent
config change) only takes effect on a **new** instance — not on one that's
already joined. To push such a change to an existing node, either apply it
by hand over SSH, or force recreation (`terraform taint`, or bump
`node_name`) to get a fresh cloud-init run.
