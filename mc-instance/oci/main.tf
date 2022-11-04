data "cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/../ubuntu-traffic-gen.tpl",
      {
        name     = var.traffic_gen.name
        internal = join(",", var.traffic_gen.internal)
        interval = var.traffic_gen.interval
        password = var.workload_password
    })
  }
}

module "this" {
  source                      = "oracle-terraform-modules/compute-instance/oci"
  version                     = "2.4.0-RC1"
  instance_count              = 1 # how many instances do you want?
  ad_number                   = 1 # AD number to provision instances. If null, instances are provisionned in a rolling manner starting with AD1
  compartment_ocid            = var.oci_compartment_ocid
  instance_display_name       = var.traffic_gen.name
  source_ocid                 = "ocid1.image.oc1.ap-singapore-1.aaaaaaaaou6afe7uzl4lqcgy7yhcign5m6qgr5ocvkhszikouq2epbh76yra"
  subnet_ocids                = [var.subnet_id]
  public_ip                   = "NONE"
  private_ips                 = [var.traffic_gen.private_ip]
  ssh_public_keys             = fileexists("~/.ssh/id_rsa.pub") ? "${file("~/.ssh/id_rsa.pub")}" : null
  block_storage_sizes_in_gbs  = [50]
  instance_flex_memory_in_gbs = 4
  shape                       = "VM.Standard.E3.Flex"
  instance_state              = "RUNNING"
  boot_volume_backup_policy   = "disabled"
  extended_metadata = {
    user_data = data.cloudinit_config.this.rendered
  }
  freeform_tags = merge(var.common_tags, {
    Name = var.traffic_gen.name
  })
}
