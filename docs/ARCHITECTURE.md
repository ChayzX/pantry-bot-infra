# Architecture

## Status: this design is live and proven, not aspirational

Earlier versions of this doc described a standalone-Docker design: separate
host-level `cloudflared` + Watchtower + Litestream containers on each VM,
coordinated by a hand-rolled leader-election lease object in R2. That design
was superseded before anything was built on it — `pantry-bot` already ran as
a real Kubernetes Deployment on a k3s cluster (`chayzx/k8s-homelab`), so this
repo makes the Oracle VM a genuine second **node** in that same cluster
instead. As of this revision, all of the following has actually happened,
not just been planned:

- The Oracle node (`pantry-bot-oracle`) is provisioned and `Ready` in the
  cluster.
- `cloudflared` runs one replica per node (anti-affinity-scheduled) — proven:
  when the previously-Pending replica finally had a second node to land on,
  it came up and served traffic.
- Litestream (Step A) is replicating to R2 — proven: a real `litestream
  restore` reproduced the exact live database, byte-for-byte row counts.
- The bot's storage moved from a node-pinned PVC to an `emptyDir` restored
  on every start (Step B, `k8s-homelab#180`) — proven with a real failover
  test: cordon home, force a reschedule onto Oracle, confirm the pod comes
  up with intact data. It did.

## The two things being solved

1. **Where the bot runs long-term.** The Oracle Cloud Always Free Ampere A1
   (ARM) node joined the home k3s cluster with real headroom (2 OCPU/12GB —
   Oracle cut this from 4 OCPU/24GB on 2026-06-15 with no notice; verify your
   own tenancy's actual current limit before raising it, see `ampere_ocpus`'s
   variable description), both to run the bot and to take on other
   `k8s-homelab` workloads. Reasoning for Oracle over GCP as primary is in
   `chayzx/pantry-bot`'s planning history — short version: GCP's Always Free
   egress cap (1GB/month) is fine for a rarely-active standby, but risky for
   a node serving live overlay/dashboard traffic every stream. Oracle's
   Always Free egress (10TB/month) doesn't have that problem.

2. **What happens when a node goes down.** This is mostly **standard
   Kubernetes behavior**, not custom logic:

   - **The bot's chat connection (single-writer constraint)**: a
     `Deployment` with `replicas: 1` guarantees exactly one pod exists
     cluster-wide. If the node running it goes unreachable, k8s's own
     node-health controller marks it `NotReady` and reschedules the pod onto
     the surviving node automatically. No bespoke lease/lock system needed.
   - **What makes that actually work**: the bot's SQLite file lives on an
     `emptyDir`, restored from the Litestream/R2 replica by an
     `initContainer` on every pod start — not a `local-path` PVC, which
     would have pinned it to whichever node created it. See
     `k8s-homelab#177`/`#180` for the full migration and the real failover
     test that proved it.
   - **The HTTP-facing surfaces** (overlay, dashboard, public commands page,
     webhook callback): `cloudflared` runs 2 replicas with pod
     anti-affinity, one per node. Cloudflare's edge already knows how to
     route to whichever connector is alive.

## The lesson this design cost an outage to learn: images must be multi-arch

Oracle's Ampere A1 is **arm64**. Home is amd64. The first real deploy after
Oracle joined caused a full outage — not because Step B's own logic was
wrong (the `restore-db` initContainer and Litestream sidecar both worked
correctly on the arm64 node), but because `ghcr.io/chayzx/pantry-bot` had
only ever been built for amd64. `strategy: Recreate` tore down the last
working pod before the replacement — which landed on the arm64 node — failed
to even pull its image. See `chayzx/pantry-bot#127` for the incident record
and `#128` for the fix (multi-arch build + a CI guardrail that fails the
build loudly if a platform is ever missing again).

**Anything that runs as a pod in this cluster now needs a multi-arch image**
(or an explicit `nodeSelector`/affinity pinning it to one architecture on
purpose) — this includes any other `k8s-homelab` workload you move onto
Oracle's spare capacity, not just pantry-bot. Worth checking before adding
anything new to this node.

## Why Tailscale

k3s agents need to reach the server's API (6443) and share a pod-network
overlay with it. Home has no stable public IP (that's what Cloudflare Tunnel
is for, and Tunnel doesn't hand you a routable cluster network). Tailscale
bridges the two over an encrypted mesh regardless of NAT/CGNAT on either
side — see `docs/ORACLE-K3S-JOIN.md` for the exact setup, including the
home-side k3s server changes this repo can't make for you.

## GCP standby: dropped from the active design, on purpose

Earlier planning included GCP's Always-Free e2-micro as a third failover leg
(home + GCP + Oracle). Once Oracle was picked as the target permanent
primary, that third leg stopped earning its complexity. **Confirmed
decision: the active failover set is home + Oracle only.** The
`terraform/gcp-standby/` stack is left in the repo, fully written,
deliberately unused — see `terraform/gcp-standby/STATUS.md`. If you're
reading this repo fresh and wondering whether GCP support is half-finished:
it isn't. It's finished and intentionally off.

## Why home stays in the loop for now

Per current plan: home keeps running as a cluster node while you confirm
Oracle is stable over real production use, not just one manual failover
test. Nothing here assumes home goes away — once you're confident, retiring
home is a matter of draining/removing that node from the cluster, not an
infra-repo change.

## Diagram

```
                         ┌──────────────────────────┐
                         │   Cloudflare Tunnel       │
                         │ (2 cloudflared replicas,  │
                         │  one per node, anti-      │
                         │  affinity-scheduled)      │
                         └────────────┬──────────────┘
                                      │
                    ┌─────────────────┴──────────────────┐
                    │         single k3s cluster          │
                    │        (spans both nodes via         │
                    │             Tailscale)               │
                    │                                      │
             ┌──────▼──────┐                      ┌────────▼────────┐
             │ Home node   │◄──── Tailscale ─────►│ Oracle A1 ARM    │
             │ (original,  │      mesh link        │ node (this repo, │
             │  unmanaged  │                       │  joined via k3s  │
             │  by TF)     │                       │  agent)          │
             └─────────────┘                       └─────────────────┘

     pantry-bot Deployment (replicas: 1) schedules onto whichever node
     is healthy; on failover it restores SQLite from the Litestream/R2
     replica into a fresh emptyDir rather than relying on a node-pinned PVC.
     PROVEN, not theoretical -- see k8s-homelab#177's closing comment.

  (GCP e2-micro standby: written, INACTIVE BY DESIGN — not part of this
   diagram on purpose. See terraform/gcp-standby/STATUS.md.)
```
