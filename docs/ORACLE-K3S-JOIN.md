# Oracle k3s: an independent single-node cluster

**Current state:** `pantry-bot-oracle` is its own k3s **server**
(control-plane), a single-node cluster that is independent of the home
cluster (`minecraftmachine` + `chasebot`). It does **not** join the home
cluster, and home does not schedule anything onto it. PantryBot runs only
here (namespace `pantry-bot`).

| | Home cluster | Oracle cluster |
|---|---|---|
| Nodes | `minecraftmachine` (control-plane), `chasebot` (agent) | `pantry-bot-oracle` (control-plane, arm64) |
| k3s role | server + agent | `k3s server`, bound to its Tailscale IP |
| PantryBot | none | all eight PantryBot Deployments + `pantry-postgres` |
| Access | `ssh minecraftmachine`, `kubectl` | `ssh oracle`, `sudo kubectl` |

The two clusters share only the tailnet. Oracle's Prometheus remote-writes
its metrics to the home observability stack through
`prometheus-write-gateway` (see `k8s-homelab/observability/`). That is the
metrics path, not cluster membership.

## History: why this file was called "K3S-JOIN"

Oracle was first provisioned (2026-09-06) as a k3s **agent** that joined the
home cluster over Tailscale. That is what `terraform/oracle-primary/` and
`terraform/modules/k3s-agent-init/` were written for. Around 2026-09-08/09
the design changed to independent k3s environments (see
`k8s-homelab/docs/superpowers/plans/2026-09-08-independent-environments-ha.md`
and `k8s-homelab/docs/recovery/NETWORK-VALIDATION.md`), because a k3s control
plane stretched over a WAN link was fragile. The node was reinstalled as a
standalone `k3s server`. The home-side prerequisites this document used to
describe (home `tls-san`/`flannel-iface` for an Oracle agent, handing Oracle
the home node-token) no longer apply.

## What the Terraform still says (known drift)

`terraform/oracle-primary/` still renders `k3s-agent-init`, which installs
Tailscale and then runs the k3s **agent** installer against `var.k3s_url` /
`var.k3s_token`. That matches the original provisioning, not the live node:

- Do **not** edit `terraform/modules/k3s-agent-init/cloud-init.yaml.tftpl`
  casually. It feeds the instance's `user_data` with no `ignore_changes`, so
  any byte change plans a **replacement** of the live Oracle VM.
- The provision-retry workflow is disabled. Do not run `terraform apply`
  against `oracle-primary` without first reviewing the plan for a replacement.
- A from-scratch rebuild needs a manual step after cloud-init: install k3s as
  a server on the Tailscale IP instead of joining home, for example
  `curl -sfL https://get.k3s.io | sh -s - server --node-ip=<ts-ip> --bind-address=<ts-ip> --advertise-address=<ts-ip> --flannel-iface=tailscale0`.
  Then re-apply the Oracle overlays from `k8s-homelab` and the PantryBot
  manifests from `chayzx/pantry-bot`'s `k8s/`. Changing the module to install
  a server is a deliberate follow-up because it forces a VM replacement.

## Verifying the current state

```bash
ssh oracle 'systemctl is-active k3s; sudo -n kubectl get nodes -o wide'
# -> active; one node, pantry-bot-oracle, Ready, control-plane
ssh minecraftmachine 'sudo -n kubectl get nodes'
# -> minecraftmachine and chasebot only; Oracle is not listed
```

## Tailscale notes (still relevant)

Both clusters reach each other only over Tailscale (metrics remote-write,
SSH, CI). The `ufw` lesson from the original join still holds on any host
that must accept traffic on `tailscale0`:

```bash
sudo ufw allow in on tailscale0
sudo ufw reload
```

Use a **reusable**, **non-ephemeral** Tailscale auth key for a rebuild, so
re-running cloud-init does not need a fresh key and a brief outage does not
remove the node from the tailnet.
