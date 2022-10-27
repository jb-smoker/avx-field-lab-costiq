locals {
  transit_firenet = {
    aws_east = {
      transit_account     = "aws-account"
      transit_cloud       = "aws"
      transit_cidr        = "10.1.0.0/23"
      transit_region_name = "us-east-1"
      transit_asn         = 65101
      transit_ha_gw       = false
    },
    azure_central = {
      transit_account     = "azure-account"
      transit_cloud       = "azure"
      transit_cidr        = "10.2.0.0/23"
      transit_region_name = "Central US"
      transit_asn         = 65102
      transit_ha_gw       = false
    },
    oci_singapore = {
      transit_account     = "oci-account"
      transit_cloud       = "oci"
      transit_cidr        = "10.3.0.0/23"
      transit_region_name = "ap-singapore-1"
      transit_asn         = 65103
      transit_ha_gw       = false
    },
    gcp_west = {
      transit_account     = "gcp-account"
      transit_cloud       = "gcp"
      transit_cidr        = "10.4.0.0/23"
      transit_region_name = "us-west1"
      transit_asn         = 65104
      transit_ha_gw       = false
    },
  }
}

# https://registry.terraform.io/modules/terraform-aviatrix-modules/mc-transit-deployment-framework/aviatrix/latest
module "framework" {
  source          = "terraform-aviatrix-modules/mc-transit-deployment-framework/aviatrix"
  version         = "v1.0.1"
  transit_firenet = local.transit_firenet
}

# https://registry.terraform.io/modules/terraform-aviatrix-modules/mc-spoke/aviatrix/latest
module "spoke_1" {
  for_each = local.transit_firenet
  source   = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version  = "1.4.1"

  cloud    = each.value.transit_cloud
  name     = "avx-${replace(lower(each.value.transit_region_name), " ", "-")}-spoke-1"
  cidr     = cidrsubnet("${trimsuffix(each.value.transit_cidr, "23")}16", 8, 2)
  region   = each.value.transit_region_name
  account  = each.value.transit_account
  attached = false
  ha_gw    = false
}

module "spoke_2" {
  for_each = { for k, v in local.transit_firenet : k => v if k != "oci_singapore" }
  source   = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version  = "1.4.1"

  cloud    = each.value.transit_cloud
  name     = "avx-${replace(lower(each.value.transit_region_name), " ", "-")}-spoke-2"
  cidr     = cidrsubnet("${trimsuffix(each.value.transit_cidr, "23")}16", 8, 3)
  region   = each.value.transit_region_name
  account  = each.value.transit_account
  attached = false
  ha_gw    = false
}

resource "aviatrix_spoke_transit_attachment" "spoke_1" {
  for_each        = local.transit_firenet
  spoke_gw_name   = module.spoke_1[each.key].spoke_gateway.gw_name
  transit_gw_name = module.framework.transit[each.key].transit_gateway.gw_name
}

resource "aviatrix_spoke_transit_attachment" "spoke_2" {
  for_each        = { for k, v in local.transit_firenet : k => v if k != "oci_singapore" }
  spoke_gw_name   = module.spoke_2[each.key].spoke_gateway.gw_name
  transit_gw_name = module.framework.transit[each.key].transit_gateway.gw_name
}
