# How this interacts with the existing deploy pipeline

`pantry-bot` already has a working CI/CD pipeline: GitHub Actions builds and
pushes an image to GHCR on every push to `main`, and Watchtower — running on
whatever host is active — polls GHCR and pulls/restarts automatically. This
repo is deliberately built to **not** duplicate or replace any part of that.
Two separate pipelines, two separate concerns:

| Pipeline | Lives in | Changes how often | Triggered by |
|---|---|---|---|
| App code deploy | `pantry-bot` (GHCR + Watchtower) | Every commit to `main` | Code changes |
| Infra provisioning | `pantry-bot-infra` (Terraform + this repo's Actions) | Rare — only when hosts change | Infra changes, or the Oracle retry schedule |

## What cloud-init does and does not do

Both VMs' cloud-init (`terraform/modules/bot-host-init/cloud-init.yaml.tftpl`)
installs Docker, `cloudflared`, Watchtower, and Litestream — and stops there.
It does **not** start the `pantry-bot` application container. That's
intentional: starting the bot unconditionally at boot would mean both the
primary and standby try to connect to Twitch chat simultaneously, which is
exactly the double-reply bug the leader-election design exists to prevent.
Instead, the `pantry-bot` leader-election sidecar (documented in that repo)
is responsible for adding the bot service to each host's `docker-compose.yml`
only after that host wins the lease.

Practically, this means:

- **A `terraform apply` here never deploys new bot code.** It only ever
  creates/resizes/replaces a VM and re-runs cloud-init. Once a VM exists,
  Watchtower — already running on it via cloud-init — takes over the actual
  app version, using the exact same GHCR polling loop as the home box always
  has. No new deploy mechanism to learn or keep in sync.
- **A code change in `pantry-bot` never touches this repo.** Watchtower pulls
  the new image on whichever host is currently leader; the standby's
  Watchtower pulls it too (harmless — it's just sitting there not running
  the bot container yet), so *whichever* host becomes leader next is already
  running current code.
- **Recreating a VM from scratch is safe.** Because the database lives in
  R2 via Litestream, not on either VM's disk, `terraform destroy` +
  `terraform apply` on either stack should never lose game data — the new VM
  restores from the replica before (if it becomes leader) starting the bot.
  This is the payoff of the backup work doing double duty here.

## One thing to watch for

If you ever change what cloud-init installs (e.g., bump the Watchtower
polling interval, add a new sidecar), that change only takes effect on a VM
the next time it's *recreated*, not on existing running VMs — cloud-init
only runs once, at first boot. For a change that needs to reach an existing
VM immediately, that's a manual SSH + `docker compose up -d` after editing
`/opt/pantry-bot/docker-compose.yml`, not a Terraform apply. Terraform will
happily show "no changes" even after you've edited the `.tftpl` file, because
from OCI/GCP's point of view the instance's `user_data` is a create-time-only
property they don't diff against a running instance the same way they diff,
say, instance size. If you need the new cloud-init to actually apply, you
need to force recreation (`terraform taint` the instance, or bump
`instance_display_name`/`instance_name`).
