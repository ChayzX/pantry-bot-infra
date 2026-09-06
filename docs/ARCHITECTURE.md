# Architecture

## Revision note

Earlier versions of this doc described a standalone-Docker design: separate
host-level `cloudflared` + Watchtower + Litestream containers on each VM,
coordinated by a hand-rolled leader-election lease object in R2. **That
design has been superseded.** `pantry-bot` already runs as a real Kubernetes
Deployment on a k3s cluster (`chayzx/k8s-homelab`), not standalone Docker —
so instead of building a parallel coordination system, this repo now makes
the Oracle VM a genuine second **node** in that same cluster, over Tailscale,
and lets Kubernetes itself do the failover.

## The two things being solved

1. **Where the bot runs long-term.** Target end state: the Oracle Cloud
   Always Free Ampere A1 (ARM) VM joins the home k3s cluster as a node with
   real headroom (defaulted to the 2 OCPU/12GB Always-Free ceiling — Oracle
   cut this from 4 OCPU/24GB on 2026-06-15; verify your own tenancy's actual
   current limit before raising it, see `ampere_ocpus`'s variable
   description),
   both to run the bot and to take on other `k8s-homelab` workloads. Reasoning
   for Oracle over GCP as primary is in `chayzx/pantry-bot`'s planning
   history — short version: GCP's Always Free egress cap (1GB/month) is fine
   for a rarely-active standby, but risky for a node serving live overlay/
   dashboard traffic every stream. Oracle's Always Free egress (10TB/month)
   doesn't have that problem.

2. **What happens when a node goes down.** Once Oracle is a real cluster
   node, this is mostly **standard Kubernetes behavior**, not custom logic:

   - **The bot's chat connection (single-writer constraint)**: a
     `Deployment` with `replicas: 1` already guarantees exactly one pod
     exists cluster-wide. If the node running it goes unreachable, k8s's own
     node-health controller marks it `NotReady` and — once the pod's
     `PersistentVolumeClaim` no longer pins it to that specific node (see
     below) — reschedules the pod onto the surviving node automatically.
     No bespoke lease/lock system needed; this is what a Deployment already
     does.
   - **The one thing that has to change to make that true**: the bot's
     SQLite file currently lives on a `local-path` PVC — literally a
     directory on the home node's disk, which does **not** follow the pod to
     Oracle on failover. The fix (tracked as a `k8s-homelab` PR, not part of
     this repo) is dropping that PVC as the source of truth in favor of an
     `emptyDir` plus a Litestream restore-on-start step, so the pod can
     actually land on either node. Litestream keeps replicating out to R2
     continuously either way — this is the same "disposable node" principle
     this repo already applies to the VM itself, just now applied to the pod.
   - **The HTTP-facing surfaces** (overlay, dashboard, public commands page,
     webhook callback): the bot's existing in-cluster `cloudflared`
     Deployment gets a second replica with pod anti-affinity, so one lands on
     each node. Cloudflare's edge already knows how to route to whichever
     connector is alive — no coordination code needed for this part either.

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

Per current plan: home keeps running as the cluster's original node while
you confirm Oracle is stable, joined correctly, and actually takes over
cleanly on a real failover test. Nothing here assumes home goes away — once
you're confident, retiring home is a matter of draining/removing that node
from the cluster, not an infra-repo change.

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

  (GCP e2-micro standby: written, INACTIVE BY DESIGN — not part of this
   diagram on purpose. See terraform/gcp-standby/STATUS.md.)
```
