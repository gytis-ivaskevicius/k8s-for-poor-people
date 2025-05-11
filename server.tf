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

locals {
  cluster_prefix = var.cluster_prefix ? "${var.cluster_name}-" : ""
  control_plane_image_id = (
    substr(var.control_plane_server_type, 0, 3) == "cax" ?
    (var.disable_arm ? null : data.hcloud_image.arm[0].id) : // Use ARM image if not disabled
    (var.disable_x86 ? null : data.hcloud_image.x86[0].id)   // Use x86 image if not disabled
  )
  control_planes = [
    for i in range(var.control_plane_count) : {
      index              = i
      name               = "${local.cluster_prefix}control-plane-${i + 1}"
      ipv4_public        = local.control_plane_public_ipv4_list[i],
      ipv6_public        = var.enable_ipv6 ? local.control_plane_public_ipv6_list[i] : null
      ipv6_public_subnet = var.enable_ipv6 ? local.control_plane_public_ipv6_subnet_list[i] : null
      ipv4_private       = local.control_plane_private_ipv4_list[i]
    }
  ]


  workers = {
    for flat_index, item in flatten([
      for name, cfg in var.workers : [
        for i in range(cfg.count) : {
          key  = "${name}-${i}"
          name = "${local.cluster_prefix}${name}-${i + 1}"
          cfg  = cfg
        }
      ]
      ]) : item.key => {
      index        = flat_index
      name         = item.name
      server_type  = item.cfg.server_type
      datacenter   = item.cfg.datacenter
      ipv4_enabled = item.cfg.ipv4_enabled
      ipv6_enabled = item.cfg.ipv6_enabled
      image = (substr(item.cfg.server_type, 0, 3) == "cax"
        ? (var.disable_arm ? null : data.hcloud_image.arm[0].id)
      : (var.disable_x86 ? null : data.hcloud_image.x86[0].id))
      labels = merge(item.cfg.labels, {
        cluster = var.cluster_name,
        role    = "worker"
      })
    }
  }

}


resource "hcloud_server" "control_planes" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  datacenter         = data.hcloud_datacenter.this.name
  name               = each.value.name
  image              = local.control_plane_image_id
  server_type        = var.control_plane_server_type
  user_data          = data.talos_machine_configuration.control_plane[each.value.name].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.control_plane.id

  labels = {
    "cluster" = var.cluster_name,
    "role"    = "control-plane"
  }

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.control_plane_ipv4[each.value.index].id
    ipv6_enabled = var.enable_ipv6
    ipv6         = var.enable_ipv6 ? hcloud_primary_ip.control_plane_ipv6[each.value.index].id : null
  }

  network {
    network_id = hcloud_network_subnet.nodes.network_id
    ip         = each.value.ipv4_private
    alias_ips  = [] # fix for https://github.com/hetznercloud/terraform-provider-hcloud/issues/650
  }

  depends_on = [
    hcloud_network_subnet.nodes,
    data.talos_machine_configuration.control_plane
  ]

  lifecycle {
    ignore_changes = [
      user_data,
      image
    ]
  }
}

resource "hcloud_server" "workers" {
  for_each           = { for worker in local.workers : worker.name => worker }
  datacenter         = each.value.datacenter
  name               = each.value.name
  image              = each.value.image
  server_type        = each.value.server_type
  user_data          = data.talos_machine_configuration.worker[each.value.name].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.worker.id

  labels = each.value.labels

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = each.value.ipv4_enabled
    ipv4         = each.value.ipv4_enabled ? hcloud_primary_ip.worker_ipv4[each.key].id : null
    ipv6_enabled = each.value.ipv6_enabled
    ipv6         = each.value.ipv6_enabled ? hcloud_primary_ip.worker_ipv6[each.key].id : null
  }

  network {
    network_id = hcloud_network_subnet.nodes.network_id
    ip         = cidrhost(hcloud_network_subnet.nodes.ip_range, each.value.index + 201)
    alias_ips  = [] # fix for https://github.com/hetznercloud/terraform-provider-hcloud/issues/650
  }

  depends_on = [
    hcloud_network_subnet.nodes,
    data.talos_machine_configuration.worker
  ]

  lifecycle {
    ignore_changes = [
      user_data,
      image
    ]
  }
}
