resource "google_compute_instance" "this" {
  name         = var.traffic_gen.name
  machine_type = "g1-small"
  zone         = "us-west1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.subnet_id
    network_ip = var.traffic_gen.private_ip
  }

  metadata_startup_script = templatefile("${path.module}/../ubuntu-traffic-gen.tpl", {
    name     = var.traffic_gen.name
    internal = join(",", var.traffic_gen.internal)
    interval = var.traffic_gen.interval
    password = var.workload_password
  })

  tags = ["workload"]
  metadata = merge(var.common_tags, {
    ssh-keys = fileexists("~/.ssh/id_rsa.pub") ? "ubuntu:${file("~/.ssh/id_rsa.pub")}" : null
  })
}

resource "google_compute_firewall" "this_ingress" {
  name    = "${var.traffic_gen.name}-ingress"
  network = var.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8", "172.16.0.0/16"]
  target_tags   = ["workload"]
}

resource "google_compute_firewall" "this_egress" {
  name      = "${var.traffic_gen.name}-egress"
  network   = var.vpc_id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["workload"]
}
