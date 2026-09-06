# Joining the Oracle VM to the home k3s cluster

Oracle's Terraform (`terraform/oracle-primary/`) makes this node a k3s
**agent** joining your existing single-node k3s cluster at home, over
Tailscale. The Oracle side is fully automated by cloud-init. The home side
is not — this repo has no access to your home k3s server, so these steps
have to happen there manually, once, before the Oracle node can join
successfully.

## Why Tailscale, briefly

Your home k3s server has no stable public IP (that's the whole reason
Cloudflare Tunnel exists for the bot's HTTP traffic), and a k3s agent needs
to reach the server's API (6443) and share a pod-network overlay with it.
Tailscale gives both boxes a stable private IP and an encrypted mesh link
regardless of NAT/CGNAT on either end — the standard pattern for exactly
this "one node at home, one in the cloud" setup.

## Home-side prerequisites (do these first, in order)

### 1. Install Tailscale on the home k3s server

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Note the Tailscale IP it's assigned: `tailscale ip -4` (looks like `100.x.y.z`).

### 2. Check `ufw` — this bit you every time before

Per `k8s-homelab/ARCHITECTURE.md`, `ufw`'s `DEFAULT_FORWARD_POLICY=DROP` was
already a "hard blocker found in review" once, for pod-to-pod traffic on the
LAN-facing interfaces. The same class of problem applies here: without an
explicit allow, `ufw` will silently drop traffic arriving on `tailscale0`
even though Tailscale itself delivered it fine.

```bash
sudo ufw allow in on tailscale0
sudo ufw reload
```

### 3. Reconfigure k3s to bind to the tailnet and use the wireguard-native backend

Edit (or create) `/etc/rancher/k3s/config.yaml`:

```yaml
flannel-backend: "wireguard-native"
node-ip: "<home-tailscale-ip>"
flannel-iface: "tailscale0"
tls-san:
  - "<home-tailscale-ip>"
```

`tls-san` matters: without it, the server's TLS certificate won't be valid
for connections arriving at its Tailscale IP, and the Oracle agent's join
will fail TLS verification.

```bash
sudo systemctl restart k3s
kubectl get nodes -o wide   # confirm the existing node is still Ready
```

### 4. Get the values Terraform needs

```bash
sudo cat /var/lib/rancher/k3s/server/node-token   # -> K3S_TOKEN
tailscale ip -4                                    # -> use in K3S_URL below
```

`K3S_URL` is `https://<that-tailscale-ip>:6443`.

### 5. Generate a Tailscale auth key

Tailscale admin console → Settings → Keys → Generate auth key. Use
**reusable** (so re-running cloud-init on a recreated instance doesn't need
a fresh key) and **not ephemeral** (so the node isn't auto-removed from the
tailnet during a brief outage).

## Feed these into GitHub Actions secrets (`pantry-bot-infra` repo settings)

- `TAILSCALE_AUTH_KEY`
- `K3S_URL`
- `K3S_TOKEN`

(These are in addition to the OCI credentials already covered in
`docs/SETUP.md`.)

## After the Oracle node joins

Verify from the home server:

```bash
kubectl get nodes -o wide
```

You should see both nodes `Ready`. Optionally label the new node so future
scheduling decisions (this bot, or other homelab workloads) can target it
deliberately:

```bash
kubectl label node pantry-bot-oracle topology.kubernetes.io/region=cloud
```

## What this does NOT do

Joining the node only makes it a schedulable member of the cluster — it
doesn't by itself move the bot or make it resilient to a node going down.
That required separate changes in `k8s-homelab`'s `pantry-bot/` manifests
(PVC → `emptyDir` + Litestream restore-on-start so the pod can actually
reschedule onto Oracle, plus a multi-arch bot image so it can even run on
arm64) and in `pantry-bot`'s own build pipeline. Those are done now — see
`docs/ARCHITECTURE.md` for the proven, tested result — but they don't live
in this repo, so a from-scratch rebuild of just this node doesn't need to
redo them.
