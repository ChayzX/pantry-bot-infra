variable "gcp_project_id" {
  description = "GCP project ID that holds your Always Free e2-micro allowance."
  type        = string
}

variable "gcp_credentials_json" {
  description = "Contents of a GCP service account key JSON file. Never commit this — pass via TF_VAR_gcp_credentials_json in CI."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "GCP region. Must be us-west1, us-central1, or us-east1 to qualify for the Always Free e2-micro."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone within the region."
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Must stay e2-micro to remain inside the Always Free tier."
  type        = string
  default     = "e2-micro"
}

variable "instance_name" {
  type    = string
  default = "pantry-bot-standby"
}

variable "ssh_public_key" {
  description = "SSH public key, format 'username:ssh-rsa AAAA...'."
  type        = string
}

variable "ssh_ingress_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "cloudflare_tunnel_token" {
  type      = string
  sensitive = true
}

variable "litestream_access_key_id" {
  type      = string
  sensitive = true
}

variable "litestream_secret_access_key" {
  type      = string
  sensitive = true
}
