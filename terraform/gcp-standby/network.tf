resource "google_compute_firewall" "ssh" {
  name    = "pantry-bot-standby-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.ssh_ingress_cidr]
  target_tags   = ["pantry-bot-standby"]
}
