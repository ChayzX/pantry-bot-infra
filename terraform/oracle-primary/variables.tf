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
    OCPUs for the VM.Standard.A1.Flex shape. Always Free covers up to 4 OCPUs
    total across all A1 instances in a tenancy. Smaller requests sometimes find
    capacity faster than requesting the full 4 — if the retry workflow runs for
    a long time at this value with no luck, try dropping it temporarily to see
    if a smaller shape finds room sooner, then grow it later with an in-place
    resize once the node exists.

    Defaulted to the full Always-Free ceiling (not a modest value) because
    this node is intended to run other k8s-homelab workloads too, not just
    the bot — see docs/ORACLE-K3S-JOIN.md.
  EOT
  type        = number
  default     = 4
}

variable "ampere_memory_gb" {
  description = "Memory (GB) for the VM.Standard.A1.Flex shape. Always Free covers up to 24GB total. Defaulted to the ceiling — see ampere_ocpus."
  type        = number
  default     = 24
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
