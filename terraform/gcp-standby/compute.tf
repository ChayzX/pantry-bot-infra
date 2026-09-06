# If you already created this box by hand before this repo existed, DO NOT
# apply this file as-is — it will try to create a duplicate. Import the
# existing instance first:
#   terraform import google_compute_instance.standby projects/<project>/zones/<zone>/instances/<name>
# See docs/SETUP.md.

resource "google_compute_instance" "standby" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["pantry-bot-standby"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30 # GB — within the Always Free 30GB standard persistent disk allowance
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {} # ephemeral public IP
  }

  metadata = {
    ssh-keys = var.ssh_public_key
    user-data = templatefile(
      "${path.module}/../modules/bot-host-init/cloud-init.yaml.tftpl",
      {
        role                         = "standby"
        cloudflare_tunnel_token      = var.cloudflare_tunnel_token
        litestream_access_key_id     = var.litestream_access_key_id
        litestream_secret_access_key = var.litestream_secret_access_key
      }
    )
  }
}
