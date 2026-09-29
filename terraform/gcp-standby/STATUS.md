# Status: INACTIVE BY DESIGN — not abandoned, not forgotten

**Do not "finish" this stack or wire it into PantryBot hosting without
checking with the user first.** This is a deliberate decision, made
explicitly, not a dropped task.

## What happened

Historical: the original plan (see `pantry-bot`'s planning history) was a
three-way failover set: home + GCP standby + Oracle primary. Once Oracle was
confirmed as the target permanent primary, GCP's only remaining role would
have been a third failover leg — redundancy without a clear need, and GCP's
Always-Free egress cap (1GB/month) makes it a poor fit for anything beyond an
occasional, rarely-active standby anyway.

**Current state: PantryBot runs ONLY on the Oracle node (single-site since
2026-09-25). GCP is not part of PantryBot hosting, and no home, Canada or GCP
standby, witness or failover exists.**

## Why this code still exists

The Terraform is fully written and harmless sitting unused — deleting it
would just mean re-deriving it later if priorities change (e.g. if a second cloud region is ever wanted for some reason).
It is intentionally NOT deleted, and intentionally NOT deployed.

## If you're an agent or a future contributor picking this repo back up

- Don't treat this directory's existence as a sign this is in progress or
  half-finished. It's finished; it's just not turned on.
- Don't run `.github/workflows/gcp-standby-apply.yml` "to catch it up" unless
  a human has explicitly asked to revive GCP hosting.
- If a GCP box already exists from earlier manual setup, see `docs/SETUP.md`
  section 3 for the `terraform import` step required before this stack could
  ever safely be applied — applying blind would create a duplicate, billed
  instance.
