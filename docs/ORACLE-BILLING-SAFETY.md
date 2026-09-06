# Oracle Cloud billing safety

Not a one-time setup step — Oracle has changed Always Free limits before
without much notice (the 2026-06-15 halving of the Ampere A1 allowance from
4 OCPU/24GB to 2 OCPU/12GB is the reason `variables.tf`'s `ampere_ocpus` /
`ampere_memory_gb` defaults are 2/12, not 4/24). Worth re-running this
checklist whenever Oracle changes something, or roughly every few months.

## Always Free compliance — verified 2026-09-06

Checked directly in the OCI Console against the live `oracle-primary`
instance:

| Check | Where | Result |
|---|---|---|
| Tenancy plan type | Billing & Cost Management → Account Management | **Free Tier** — not a Pay-As-You-Go account quietly sitting at $0 |
| Compute shape | Compute → Instances → instance details | Ampere A1.Flex, **2 OCPU / 12GB** — matches the current (post-2026-06-15) Always Free allowance and the Terraform default |
| Boot volume | Compute → Instances → Boot Volume | **47GB** — comfortably under the 200GB total Always Free block-storage allowance |
| Public IP | Compute → Instances → Primary VNIC → IP Management | **Ephemeral** — no Reserved IP in use, so no separate reserved-IP allowance to track |

No further action needed from this pass. If a future Terraform change bumps
`ampere_ocpus`/`ampere_memory_gb`, or if Oracle changes the free allowance
again, re-check the shape row above before applying.

## Budget alert — configured 2026-09-06

A budget was created in Billing & Cost Management → Budgets:

- **Scope:** root/main compartment (covers the whole tenancy, not just this
  one instance — anything else created in this account trips it too)
- **Amount:** $1/month — small enough that any real charge, not just a
  large one, triggers it
- **Reset period:** Monthly
- **Alert rule:** threshold at the smallest percentage the console allowed,
  emailed to the account owner's address

This means: if Oracle ever bills this tenancy for anything at all — a
free-tier policy change, an accidentally-created non-free resource, a
forgotten reserved IP — an email goes out before it becomes a real bill,
not after.

## If the alert ever fires

1. Don't panic — $1 threshold means this catches things early, not after
   real money is owed.
2. Check Billing & Cost Management → Cost Analysis for which resource is
   generating the charge.
3. Cross-reference against `terraform/oracle-primary/` and
   `terraform/gcp-standby/` (should still be `terraform destroy`'d / never
   applied — see its `STATUS.md`) to see if it's something Terraform
   created outside the expected free-tier shape, or something created
   manually outside Terraform entirely (the latter is the more likely
   culprit — see this repo's CLAUDE.md note about not hand-managing
   resources Terraform is supposed to own).
4. Delete/resize the offending resource, or adjust `variables.tf` and
   re-apply if the free allowance itself changed.
