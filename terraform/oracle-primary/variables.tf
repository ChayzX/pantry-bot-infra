variable "oci_tenancy_ocid" {
  description = "OCI tenancy OCID."
  type        = string
}

variable "oci_user_ocid" {
  description = "OCI user OCID used for API auth."
  type        = string
}

variable "oci_fingerprint" {
  description = "Fingerprint of the OCI API signing key."
  type        = string
}

variable "oci_private_key" {
  description = "PEM contents of the OCI API signing key. Never commit this — pass via TF_VAR_oci_private_key in CI."
  type        = string
  sensitive   = true
}

variable "oci_region" {
  description = "OCI region that holds your tenancy's Always Free Ampere A1 capacity, e.g. us-ashburn-1."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID to create resources in (root compartment is fine for a single-project tenancy)."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key installed on the instance for management access."
  type        = string
}

variable "ampere_ocpus" {
  description = <<-EOT
    OCPUs for the VM.Standard.A1.Flex shape.

    IMPORTANT: Oracle cut the Always Free Ampere A1 allowance on 2026-06-15
    from 4 OCPU/24GB down to 2 OCPU/12GB total per tenancy. Verify your own
    tenancy's current limit (Governance & Administration -> Limits, Quotas
    and Usage -> filter on "VM.Standard.A1.Flex") before raising this —
    requesting more than your tenancy's actual Always Free ceiling either
    fails outright or, worse, silently starts billing as a paid shape.
    Defaulted to 2 here to match the post-cut ceiling; only raise it after
    confirming your tenancy's real limit.

    Smaller requests sometimes find capacity faster than requesting the full
    amount — if the retry workflow runs for a long time with no luck, try
    dropping this further temporarily, then grow it later with an in-place
    resize once the node exists.
  EOT
  type        = number
  default     = 2
}

variable "ampere_memory_gb" {
  description = <<-EOT
    Memory (GB) for the VM.Standard.A1.Flex shape. Defaulted to 12 to match
    the post-2026-06-15 Always Free ceiling (2 OCPU/12GB total per tenancy,
    down from 4 OCPU/24GB) — see ampere_ocpus for why this matters and how
    to verify your own tenancy's actual limit before raising it.
  EOT
  type        = number
  default     = 12
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to reach SSH (22/tcp). Restrict this to your own IP/VPN range in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tailscale_auth_key" {
  description = <<-EOT
    Tailscale auth key this node uses to join your tailnet. Generate a
    reusable, ephemeral-off key (Settings -> Keys) scoped to this purpose —
    reusable so re-running cloud-init on a recreated instance doesn't need a
    fresh key each time, ephemeral-off so the node isn't removed from the
    tailnet if it's briefly offline.
  EOT
  type        = string
  sensitive   = true
}

variable "k3s_url" {
  description = "URL of the home k3s server over Tailscale, e.g. https://100.x.y.z:6443. See docs/ORACLE-K3S-JOIN.md for how to get this."
  type        = string
}

variable "k3s_token" {
  description = "Join token from the home k3s server (/var/lib/rancher/k3s/server/node-token). Never commit this."
  type        = string
  sensitive   = true
}

variable "node_name" {
  description = "Name this node registers under in the cluster and in Tailscale."
  type        = string
  default     = "pantry-bot-oracle"
}
