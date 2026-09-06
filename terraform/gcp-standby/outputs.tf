output "public_ip" {
  description = "Public IP of the GCP standby VM."
  value       = google_compute_instance.standby.network_interface[0].access_config[0].nat_ip
}
