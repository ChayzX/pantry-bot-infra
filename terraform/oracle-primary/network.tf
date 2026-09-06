# Minimal networking: one VCN, one public subnet, SSH in / everything out.
# cloudflared makes only outbound connections, so no inbound rule is needed
# for the tunnel itself.

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.20.0.0/16"]
  display_name   = "pantry-bot-vcn"
  dns_label      = "pantrybotvcn"
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "pantry-bot-igw"
  enabled        = true
}

resource "oci_core_route_table" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "pantry-bot-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_security_list" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "pantry-bot-seclist"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    source   = var.ssh_ingress_cidr
    protocol = "6" # TCP
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Tailscale can operate purely on outbound-initiated connections (falling
  # back to a relay/DERP server), but opening its direct-connection port
  # lets it establish a peer-to-peer link to home instead of relaying k3s's
  # pod traffic through a third party — meaningfully better latency for the
  # cluster's cross-node network.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "17" # UDP
    udp_options {
      min = 41641
      max = 41641
    }
  }
}

resource "oci_core_subnet" "this" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = "10.20.0.0/24"
  display_name               = "pantry-bot-subnet"
  dns_label                  = "pantrybotsub"
  route_table_id             = oci_core_route_table.this.id
  security_list_ids          = [oci_core_security_list.this.id]
  prohibit_public_ip_on_vnic = false
}
