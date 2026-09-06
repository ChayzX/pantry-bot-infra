data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

# Latest arm64 Ubuntu image compatible with the A1.Flex shape.
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "primary" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.instance_display_name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ampere_ocpus
    memory_in_gbs = var.ampere_memory_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.this.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "${path.module}/../modules/bot-host-init/cloud-init.yaml.tftpl",
      {
        role                         = "primary"
        cloudflare_tunnel_token      = var.cloudflare_tunnel_token
        litestream_access_key_id     = var.litestream_access_key_id
        litestream_secret_access_key = var.litestream_secret_access_key
      }
    ))
  }

  # OCI's Always-Free Ampere capacity is contended — creation can fail with
  # "Out of host capacity" at the API level. Terraform itself doesn't retry
  # that; the retry-until-provisioned loop lives one level up, in
  # .github/workflows/oracle-provision-retry.yml, which re-runs `terraform
  # apply` on a schedule until this resource is created successfully.
  lifecycle {
    create_before_destroy = false
  }
}
