variable "network_ipv4_cidr" {
  description = "The main network cidr that all subnets will be created upon."
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_ipv4_cidr" {
  description = "Node CIDR, used for the nodes (control plane and worker nodes) in the cluster."
  type        = string
  default     = "10.0.1.0/24"
}

variable "pod_ipv4_cidr" {
  description = "Pod CIDR, used for the pods in the cluster."
  type        = string
  default     = "10.0.16.0/20"
}

variable "service_ipv4_cidr" {
  description = "Service CIDR, used for the services in the cluster."
  type        = string
  default     = "10.0.8.0/21"
}

locals {
  # https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/main/docs/deploy_with_networks.md#considerations-on-the-ip-ranges
  node_ipv4_cidr_mask_size = split("/", var.node_ipv4_cidr)[1] # 24
}

resource "hcloud_network" "this" {
  name     = var.cluster_name
  ip_range = var.network_ipv4_cidr
  labels = {
    "cluster" = var.cluster_name
  }
}

resource "hcloud_network_subnet" "nodes" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = data.hcloud_location.this.network_zone
  ip_range     = var.node_ipv4_cidr
}

locals {
  create_floating_ip = var.enable_floating_ip && var.floating_ip == null
}

resource "hcloud_floating_ip" "control_plane_ipv4" {
  count             = local.create_floating_ip ? 1 : 0
  name              = "${local.cluster_prefix}control-plane-ipv4"
  type              = "ipv4"
  home_location     = data.hcloud_location.this.name
  description       = "Control Plane VIP"
  delete_protection = false
  labels = {
    "cluster" = var.cluster_name,
    "role"    = "control-plane"
  }
}

data "hcloud_floating_ip" "control_plane_ipv4" {
  count = var.enable_floating_ip ? 1 : 0
  id = coalesce(
    can(var.floating_ip.id) ? var.floating_ip.id : null,
    local.create_floating_ip ? hcloud_floating_ip.control_plane_ipv4[0].id : null
  )
}

resource "hcloud_floating_ip_assignment" "this" {
  count          = local.create_floating_ip ? 1 : 0
  floating_ip_id = data.hcloud_floating_ip.control_plane_ipv4[0].id
  server_id      = hcloud_server.control_planes[local.control_planes[0].name].id
  depends_on = [
    hcloud_server.control_planes,
  ]
}

resource "hcloud_primary_ip" "control_plane_ipv4" {
  for_each      = { for k, v in local.control_planes : v.name => v if v.ipv4_enabled }
  name          = "${each.value.name}-ipv4"
  datacenter    = each.value.datacenter
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  labels        = each.value.labels
}

resource "hcloud_primary_ip" "control_plane_ipv6" {
  for_each      = { for k, v in local.control_planes : v.name => v if v.ipv6_enabled }
  name          = "${each.value.name}-ipv6"
  datacenter    = each.value.datacenter
  type          = "ipv6"
  assignee_type = "server"
  auto_delete   = false
  labels        = each.value.labels
}

resource "hcloud_primary_ip" "worker_ipv4" {
  for_each      = { for k, v in local.workers : v.name => v if v.ipv4_enabled }
  name          = "${each.value.name}-ipv4"
  datacenter    = each.value.datacenter
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  labels        = each.value.labels
}

resource "hcloud_primary_ip" "worker_ipv6" {
  for_each      = { for k, v in local.workers : v.name => v if v.ipv6_enabled }
  name          = "${each.value.name}-ipv6"
  datacenter    = each.value.datacenter
  type          = "ipv6"
  assignee_type = "server"
  auto_delete   = false
  labels        = each.value.labels
}

locals {
  control_plane_public_ipv4_list = [
    for ipv4 in hcloud_primary_ip.control_plane_ipv4 : ipv4.ip_address
  ]
  control_plane_public_ipv6_list = [
    for ipv6 in hcloud_primary_ip.control_plane_ipv6 : ipv6.ip_address
  ]

  # https://docs.hetzner.com/cloud/networks/faq/#are-any-ip-addresses-reserved
  # We may not use th following IP addresses:
  # - The first IP address of your network IP range. For example, in 10.0.0.0/8, you cannot use 10.0.0.1.
  # - The network and broadcast IP addresses of any subnet. For example, in 10.0.0.0/24, you cannot use 10.0.0.0 as well as 10.0.0.255.
  # - The special private IP address 172.31.1.1. This IP address is being used as a default gateway of your server's public network interface.
  control_plane_private_vip_ipv4 = cidrhost(hcloud_network_subnet.nodes.ip_range, 100)
  control_plane_private_ipv4_list = [
    for index in range(length(local.control_planes)) : cidrhost(hcloud_network_subnet.nodes.ip_range, index + 101)
  ]
}
