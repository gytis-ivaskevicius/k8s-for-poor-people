locals {
  worker_yaml = {
    for worker in local.workers : worker.name => {
      machine = {
        install = {
          image = "ghcr.io/siderolabs/installer:${var.talos_version}"
          extraKernelArgs = [
            "ipv6.disable=${var.enable_ipv6 ? 0 : 1}",
          ]
        }
        certSANs = local.cert_SANs
        kubelet = {
          extraArgs = merge(
            {
              "cloud-provider"             = "external"
              "rotate-server-certificates" = true
            },
            var.kubelet_extra_args
          )
          nodeIP = {
            validSubnets = [
              local.node_ipv4_cidr
            ]
          }
        }
        network = {
          extraHostEntries = local.extra_host_entries
          kubespan = {
            enabled = var.enable_kube_span
            advertiseKubernetesNetworks : false # Disabled because of cilium
            mtu : 1370                          # Hcloud has a MTU of 1450 (KubeSpanMTU = UnderlyingMTU - 80)
          }
        }
        kernel = {
          modules = var.kernel_modules_to_load
        }
        sysctls = merge(
          {
            "net.core.somaxconn"          = "65535"
            "net.core.netdev_max_backlog" = "4096"
          },
          var.sysctls_extra_args
        )
        features = {
          hostDNS = {
            enabled              = true
            forwardKubeDNSToHost = true
            resolveMemberNames   = true
          }
        }
        time = {
          servers = [
            "ntp1.hetzner.de",
            "ntp2.hetzner.com",
            "ntp3.hetzner.net",
            "time.cloudflare.com"
          ]
        }
        registries = var.registries
      }
      cluster = {
        network = {
          dnsDomain = var.cluster_domain
          podSubnets = [
            local.pod_ipv4_cidr
          ]
          serviceSubnets = [
            local.service_ipv4_cidr
          ]
          cni = {
            name = "none"
          }
        }
      }
    }
  }

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
      image        = substr(item.cfg.server_type, 0, 3) == "cax" ? (var.disable_arm ? null : data.hcloud_image.arm[0].id) : (var.disable_x86 ? null : data.hcloud_image.x86[0].id)
      labels = merge(item.cfg.labels, {
        cluster = var.cluster_name,
        role    = "worker"
      })
    }
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
