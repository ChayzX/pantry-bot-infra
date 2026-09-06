terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }

  # Cloudflare R2 is S3-compatible, so the plain "s3" backend works against it.
  # Account-specific values (bucket, endpoint, access keys) are supplied via
  # `-backend-config` at `terraform init` time — see docs/SETUP.md — so
  # nothing account-specific is committed here.
  backend "s3" {
    key                         = "pantry-bot-infra/oracle-primary.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
