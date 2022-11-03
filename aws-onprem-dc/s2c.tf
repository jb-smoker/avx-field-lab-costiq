locals {
  name = "aws-onprem-dc"
}
resource "aviatrix_vpc" "this" {
  cloud_type           = 1
  region               = var.region
  account_name         = var.account_name
  name                 = local.name
  cidr                 = var.cidr
  aviatrix_transit_vpc = false
  aviatrix_firenet_vpc = false
}

resource "aws_customer_gateway" "this" {
  bgp_asn    = var.asn
  ip_address = "54.205.99.167"
  type       = "ipsec.1"

  tags = merge(var.common_tags, {
    Name = "${local.name}-acg"
  })
}

resource "aws_customer_gateway" "this_ha" {
  bgp_asn    = var.asn
  ip_address = "54.211.31.191"
  type       = "ipsec.1"

  tags = merge(var.common_tags, {
    Name = "${local.name}-acg-ha"
  })
}

resource "aws_vpn_gateway" "this" {
  vpc_id          = aviatrix_vpc.this.vpc_id
  amazon_side_asn = 65000

  tags = merge(var.common_tags, {
    Name = local.name
  })
}

resource "aws_vpn_connection" "this" {
  vpn_gateway_id        = aws_vpn_gateway.this.id
  customer_gateway_id   = aws_customer_gateway.this.id
  type                  = "ipsec.1"
  static_routes_only    = false
  tunnel1_inside_cidr   = "169.254.100.0/30"
  tunnel1_preshared_key = var.workload_password
}

resource "aws_vpn_connection" "this_ha" {
  vpn_gateway_id        = aws_vpn_gateway.this.id
  customer_gateway_id   = aws_customer_gateway.this_ha.id
  type                  = "ipsec.1"
  static_routes_only    = false
  tunnel1_inside_cidr   = "169.254.101.0/30"
  tunnel1_preshared_key = var.workload_password
}

resource "aviatrix_transit_external_device_conn" "this" {
  vpc_id             = aviatrix_vpc.this.vpc_id
  connection_name    = local.name
  gw_name            = var.transit_gw_name
  connection_type    = "bgp"
  bgp_local_as_num   = var.asn
  bgp_remote_as_num  = 65000
  remote_gateway_ip  = "${aws_vpn_connection.this.tunnel1_address},${aws_vpn_connection.this_ha.tunnel1_address}"
  pre_shared_key     = var.workload_password
  local_tunnel_cidr  = "169.254.100.2/30,169.254.101.2/30"
  remote_tunnel_cidr = "169.254.100.1/30,169.254.101.1/30"
}

resource "aws_route" "s2c" {
  count                  = 12
  route_table_id         = aviatrix_vpc.this.route_tables[count.index]
  destination_cidr_block = "10.0.0.0/8"
  gateway_id             = aws_vpn_gateway.this.id
}
