provider "google" {
  project     = var.gcp_project_id
  region      = var.region
  credentials = var.gcp_credentials_json
}
