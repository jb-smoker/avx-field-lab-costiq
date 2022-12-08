locals {
  transit_firenet = {
    aws_east = {
      transit_account     = var.aws_account
      transit_cloud       = "aws"
      transit_cidr        = "10.1.0.0/23"
      transit_region_name = "us-east-1"
      transit_asn         = 65101
      transit_ha_gw       = false
    },
    azure_central = {
      transit_account     = var.azure_account
      transit_cloud       = "azure"
      transit_cidr        = "10.2.0.0/23"
      transit_region_name = "Central US"
      transit_asn         = 65102
      htransit_ha_gwa_gw  = false
    },
    oci_singapore = {
      transit_account     = var.oci_account
      transit_cloud       = "oci"
      transit_cidr        = "10.3.0.0/23"
      transit_region_name = "ap-singapore-1"
      transit_asn         = 65103
      transit_ha_gw       = false
    },
    gcp_west = {
      transit_account     = var.gcp_account
      transit_cloud       = "gcp"
      transit_cidr        = "10.4.0.0/23"
      transit_region_name = "us-west1"
      transit_asn         = 65104
      transit_ha_gw       = false
    },
  }
  hr_host         = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.aws_east.transit_cidr, "23")}16", 8, 2), 10)
  accounting_host = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.aws_east.transit_cidr, "23")}16", 8, 3), 10)
  marketing_host  = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.gcp_west.transit_cidr, "23")}16", 8, 2), 10)
  ml_host         = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.gcp_west.transit_cidr, "23")}16", 8, 3), 10)
  shared_db_host  = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.oci_singapore.transit_cidr, "23")}16", 8, 2), 20)
  eng_dev_host    = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.azure_central.transit_cidr, "23")}16", 8, 2), 40)
  eng_prod_host   = cidrhost(cidrsubnet("${trimsuffix(local.transit_firenet.azure_central.transit_cidr, "23")}16", 8, 3), 40)
  onprem_host     = cidrhost(local.onprem_cidr, 10)
  onprem_cidr     = "172.16.0.0/16"
  traffic_gen = {
    hr = {
      private_ip = local.hr_host
      name       = "human-resources-app"
      internal   = [local.onprem_host, local.shared_db_host]
      interval   = "6"
    }
    accounting = {
      private_ip = local.accounting_host
      name       = "accounting-app"
      internal   = [local.shared_db_host]
      interval   = "2"
    }
    marketing = {
      private_ip = local.marketing_host
      name       = "marketing-app"
      internal   = [local.onprem_host, local.shared_db_host]
      interval   = "4"
    }
    eng_dev = {
      private_ip = local.eng_dev_host
      name       = "engineering-dev-app"
      internal   = [local.onprem_host, local.shared_db_host, local.ml_host]
      interval   = "6"
    }
    eng_prod = {
      private_ip = local.eng_prod_host
      name       = "engineering-prod-app"
      internal   = [local.onprem_host, local.shared_db_host, local.ml_host]
      interval   = "2"
    }
    shared_db = {
      private_ip = local.shared_db_host
      name       = "shared-db"
      internal   = [local.hr_host, local.accounting_host, local.marketing_host, local.eng_dev_host, local.eng_prod_host]
      interval   = "6"
    }
    ml = {
      private_ip = local.ml_host
      name       = "ml-app"
      internal   = [local.eng_dev_host, local.eng_prod_host, local.marketing_host]
      interval   = "6"
    }
    onprem_dc = {
      private_ip = local.onprem_host
      name       = "on-prem-app"
      internal   = [local.hr_host, local.marketing_host, local.eng_dev_host, local.eng_prod_host]
      interval   = "6"
    }
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

  cloud      = each.value.transit_cloud
  name       = "avx-${replace(lower(each.value.transit_region_name), " ", "-")}-spoke-1"
  cidr       = cidrsubnet("${trimsuffix(each.value.transit_cidr, "23")}16", 8, 2)
  region     = each.value.transit_region_name
  account    = each.value.transit_account
  transit_gw = module.framework.transit[each.key].transit_gateway.gw_name
  attached   = true
  ha_gw      = false
}

module "spoke_2" {
  for_each = { for k, v in local.transit_firenet : k => v if k != "oci_singapore" }
  source   = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version  = "1.4.1"

  cloud      = each.value.transit_cloud
  name       = "avx-${replace(lower(each.value.transit_region_name), " ", "-")}-spoke-2"
  cidr       = cidrsubnet("${trimsuffix(each.value.transit_cidr, "23")}16", 8, 3)
  region     = each.value.transit_region_name
  account    = each.value.transit_account
  transit_gw = module.framework.transit[each.key].transit_gateway.gw_name
  attached   = true
  ha_gw      = false
}

module "aws_onprem_dc" {
  source          = "./aws-onprem-dc"
  vpc_id          = module.framework.transit["aws_east"].vpc.vpc_id
  region          = local.transit_firenet.aws_east.transit_region_name
  account_name    = local.transit_firenet.aws_east.transit_account
  transit_gw_name = module.framework.transit["aws_east"].transit_gateway.gw_name
  cidr            = local.onprem_cidr
  asn             = local.transit_firenet.aws_east.transit_asn
  transit_eip     = module.framework.transit["aws_east"].transit_gateway.eip
  transit_ha_eip  = module.framework.transit["aws_east"].transit_gateway.ha_eip
  common_tags     = var.common_tags
}

module "workload_onprem_dc" {
  source      = "./mc-instance"
  vpc_id      = module.aws_onprem_dc.vpc.vpc_id
  subnet_id   = module.aws_onprem_dc.vpc.private_subnets[0].subnet_id
  key_name    = var.key_name
  cloud       = local.transit_firenet.aws_east.transit_cloud
  traffic_gen = local.traffic_gen.onprem_dc
  common_tags = merge(var.common_tags, {
    Location    = "Onprem Data Center"
    Application = "Onprem App"
    Environment = "Production"
  })
  workload_password = var.workload_password
}

module "workload_hr" {
  source               = "./mc-instance"
  vpc_id               = module.spoke_1["aws_east"].vpc.vpc_id
  subnet_id            = module.spoke_1["aws_east"].vpc.private_subnets[0].subnet_id
  key_name             = var.key_name
  cloud                = local.transit_firenet.aws_east.transit_cloud
  traffic_gen          = local.traffic_gen.hr
  iam_instance_profile = aws_iam_instance_profile.ec2_role_for_ssm.name
  common_tags = merge(var.common_tags, {
    Department  = "Human Resources"
    Application = "HR App"
    Environment = "Production"
  })
  workload_password = var.workload_password
}

module "workload_accounting" {
  source               = "./mc-instance"
  vpc_id               = module.spoke_2["aws_east"].vpc.vpc_id
  subnet_id            = module.spoke_2["aws_east"].vpc.private_subnets[0].subnet_id
  key_name             = var.key_name
  cloud                = local.transit_firenet.aws_east.transit_cloud
  traffic_gen          = local.traffic_gen.accounting
  iam_instance_profile = aws_iam_instance_profile.ec2_role_for_ssm.name
  common_tags = merge(var.common_tags, {
    Department  = "Accounting"
    Application = "Accounting App"
    Environment = "Production"
  })
  workload_password = var.workload_password
}

module "workload_eng_dev" {
  source         = "./mc-instance"
  resource_group = module.spoke_1["azure_central"].vpc.resource_group
  subnet_id      = module.spoke_1["azure_central"].vpc.private_subnets[0].subnet_id
  location       = local.transit_firenet.azure_central.transit_region_name
  cloud          = local.transit_firenet.azure_central.transit_cloud
  traffic_gen    = local.traffic_gen.eng_dev
  common_tags = merge(var.common_tags, {
    Department  = "Engineering"
    Application = "Engineering App"
    Environment = "Development"
  })
  workload_password = var.workload_password
}

module "workload_eng_prod" {
  source         = "./mc-instance"
  resource_group = module.spoke_2["azure_central"].vpc.resource_group
  subnet_id      = module.spoke_2["azure_central"].vpc.private_subnets[0].subnet_id
  location       = local.transit_firenet.azure_central.transit_region_name
  cloud          = local.transit_firenet.azure_central.transit_cloud
  traffic_gen    = local.traffic_gen.eng_prod
  common_tags = merge(var.common_tags, {
    Department  = "Engineering"
    Application = "Engineering App"
    Environment = "Production"
  })
  workload_password = var.workload_password
}

module "workload_shared_db" {
  source               = "./mc-instance"
  oci_compartment_ocid = var.oci_compartment_ocid
  subnet_id            = module.spoke_1["oci_singapore"].vpc.private_subnets[0].subnet_id
  cloud                = local.transit_firenet.oci_singapore.transit_cloud
  traffic_gen          = local.traffic_gen.shared_db
  common_tags = merge(var.common_tags, {
    Application = "Shared Oracle Database"
    Environment = "Production"
  })
  workload_password = var.workload_password
}

module "workload_marketing" {
  source      = "./mc-instance"
  vpc_id      = module.spoke_1["gcp_west"].vpc.name
  subnet_id   = module.spoke_1["gcp_west"].vpc.subnets[0].name
  cloud       = local.transit_firenet.gcp_west.transit_cloud
  region      = local.transit_firenet.gcp_west.transit_region_name
  traffic_gen = local.traffic_gen.marketing
  common_tags = merge(var.common_tags, {
    Department  = "Marketing"
    Application = "Marketing App"
    Environment = "Production"
  })
  workload_password = var.workload_password
}

module "workload_ml" {
  source      = "./mc-instance"
  vpc_id      = module.spoke_2["gcp_west"].vpc.name
  subnet_id   = module.spoke_2["gcp_west"].vpc.subnets[0].name
  cloud       = local.transit_firenet.gcp_west.transit_cloud
  region      = local.transit_firenet.gcp_west.transit_region_name
  traffic_gen = local.traffic_gen.ml
  common_tags = merge(var.common_tags, {
    Application = "ML App"
    Environment = "Production"
  })
  workload_password = var.workload_password
}
