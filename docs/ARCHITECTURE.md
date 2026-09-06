# Architecture

## The two things being solved

1. **Where the bot runs long-term.** Target end state: the Oracle Cloud Always
   Free Ampere A1 (ARM) VM is primary, always on, no dependency on your home
   power or internet. Reasoning for why Oracle over GCP as the *primary* is in
   `chayzx/pantry-bot`'s planning history — short version: GCP's Always Free
   e2-micro egress cap (1GB/month) is fine for a standby that's rarely serving
   traffic, but risky for something serving an OBS overlay + dashboard every
   stream. Oracle's Always Free egress (10TB/month) doesn't have that problem.

2. **What happens when the active host goes down.** This repo provisions the
   VMs; `chayzx/pantry-bot` owns the actual failover logic. The two meet at:
   - **cloudflared replicas** — both VMs run `cloudflared` against the *same*
     Cloudflare Tunnel. Cloudflare's edge automatically stops routing to
     whichever replica drops its connection. This handles the HTTP-facing
     surfaces (overlay, dashboard, public commands page, webhook callback)
     with no leader election needed — it's just "route to whoever's up."
   - **Leader election for the chat connection** — only one process may hold
     the Twitch IRC connection at a time, or every command gets answered
     twice. A small lease object in the same R2 bucket Litestream already
     replicates the database into decides who's "it." Whichever host holds
     a live lease starts the actual `pantry-bot` application container;
     everyone else stays passive.
   - **Litestream** replicates SQLite continuously to R2. Whichever host
     becomes leader restores from that replica before starting — this is why
     both VMs here are cloud-init'd as *disposable*: neither one's local disk
     is the source of truth.

## GCP standby: dropped from the active design, on purpose

Earlier planning included GCP's Always-Free e2-micro as a third failover leg
(home + GCP + Oracle). Once Oracle was picked as the target permanent
primary, that third leg stopped earning its complexity — it was only ever a
stopgap standby from before Oracle was in the picture. **Confirmed decision:
the active failover set is home + Oracle only.** The `terraform/gcp-standby/`
stack is left in the repo, fully written, deliberately unused — see
`terraform/gcp-standby/STATUS.md`. If you're reading this repo fresh and
wondering whether GCP support is half-finished: it isn't. It's finished and
intentionally off.

## Why home stays in the loop for now

Per current plan: home keeps running as a second failover target alongside
GCP while you confirm the Oracle box is stable. Nothing in this repo assumes
home goes away — it's just not Terraform-managed, since it's physical
hardware you already administer directly. Once you're confident, retiring
home from the failover set is a `pantry-bot`-side config change (fewer
lease-checking replicas), not an infra-repo change.

## Diagram

```
                     ┌─────────────────────────┐
                     │   Cloudflare Tunnel      │
                     │ (single tunnel, 2        │
                     │  replicas connected)     │
                     └───────────┬─────────────┘
                    ┌────────────┴─────────────┐
                    │                           │
             ┌──────▼──────┐            ┌───────▼───────┐
             │ Home PC     │            │ Oracle A1 ARM │
             │ (existing,  │            │ (primary,     │
             │  unmanaged  │            │  this repo)   │
             │  by TF)     │            │               │
             └──────┬──────┘            └───────┬───────┘
                    │                           │
                    └─────────────┬─────────────┘
                     both watch the same
                  R2 lease object + Litestream
                       replica of pantry.db

  (GCP e2-micro standby: written, INACTIVE BY DESIGN — not part of this
   diagram on purpose. See terraform/gcp-standby/STATUS.md.)
```
