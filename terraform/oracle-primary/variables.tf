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

variable "instance_display_name" {
  description = "Display name for the compute instance."
  type        = string
  default     = "pantry-bot-primary"
}

variable "ampere_ocpus" {
  description = <<-EOT
    OCPUs for the VM.Standard.A1.Flex shape. Always Free covers up to 4 OCPUs
    total across all A1 instances in a tenancy. Smaller requests sometimes find
    capacity faster than requesting the full 4 — the retry workflow will keep
    trying at whatever value is set here, so start modest (this bot's workload
    is tiny) and raise it later if you want headroom for the whole dashboard
    stack.
  EOT
  type        = number
  default     = 2
}

variable "ampere_memory_gb" {
  description = "Memory (GB) for the VM.Standard.A1.Flex shape. Always Free covers up to 24GB total."
  type        = number
  default     = 12
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to reach SSH (22/tcp). Restrict this to your own IP/VPN range in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "cloudflare_tunnel_token" {
  description = "Token for the existing Cloudflare Tunnel this VM joins as an additional replica."
  type        = string
  sensitive   = true
}

variable "litestream_access_key_id" {
  description = "R2 access key ID used by litestream to restore/replicate the SQLite database."
  type        = string
  sensitive   = true
}

variable "litestream_secret_access_key" {
  description = "R2 secret access key used by litestream."
  type        = string
  sensitive   = true
}
