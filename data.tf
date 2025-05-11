
locals {
  cluster_prefix = var.cluster_prefix ? "${var.cluster_name}-" : ""
}

data "hcloud_datacenter" "this" {
  name = var.datacenter_name
}

data "hcloud_location" "this" {
  id = data.hcloud_datacenter.this.location.id
}

data "hcloud_image" "arm" {
  count             = var.disable_arm ? 0 : 1
  with_selector     = "os=talos"
  with_architecture = "arm"
  most_recent       = true
}

data "hcloud_image" "x86" {
  count             = var.disable_x86 ? 0 : 1
  with_selector     = "os=talos"
  with_architecture = "x86"
  most_recent       = true
}

# The cluster should be healthy after cilium is installed
# It's actually not helpful because of https://github.com/siderolabs/talos/issues/7967#issuecomment-2003751512
#data "talos_cluster_health" "this" {
#  depends_on           = [data.helm_template.cilium]
#  client_configuration = data.talos_client_configuration.this.client_configuration
#  endpoints            = local.control_plane_public_ipv4_list
#  control_plane_nodes  = local.control_plane_private_ipv4_list
#  worker_nodes         = local.worker_private_ipv4_list
#}

data "http" "talos_health" {
  url      = "https://${local.control_plane_public_ipv4_list[0]}:${local.api_port_k8s}/version"
  insecure = true
  retry {
    attempts     = 60
    min_delay_ms = 5000
    max_delay_ms = 5000
  }
  depends_on = [talos_machine_bootstrap.this]
}
