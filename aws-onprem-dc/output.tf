output "vpc" {
  description = "The created VPC as an object with all of it's attributes. This was created using the aviatrix_vpc resource."
  value       = aviatrix_vpc.this
}

output "aviatrix_transit_external_device_conn_name" {
  description = "The name of the Aviatrix S2C External Connection"
  value       = aviatrix_transit_external_device_conn.this.connection_name
}
