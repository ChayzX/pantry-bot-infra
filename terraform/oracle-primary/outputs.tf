output "public_ip" {
  description = "Public IP of the Oracle primary VM."
  value       = oci_core_instance.primary.public_ip
}

output "instance_ocid" {
  description = "OCID of the Oracle primary compute instance."
  value       = oci_core_instance.primary.id
}
