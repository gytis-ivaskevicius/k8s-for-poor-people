variable "control_planes" {
  description = "Control plane definition"
  type = map(object({
    server_type     = string
    datacenter      = string
    labels          = optional(map(string), {})
    count           = optional(number, 1)
    ipv4_enabled    = optional(bool, true)
    ipv6_enabled    = optional(bool, false)
    extra_user_data = optional(map(any))
  }))
  default = {}
}

variable "allow_scheduling_on_control_planes" {
  type        = bool
  default     = true
  description = "If true, the control plane nodes will be allowed to schedule pods."
}

locals {
  controlplane_yaml = {
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
            var.node_ipv4_cidr
          ]
        }
      }
      network = {
        interfaces = [
          {
            interface = "eth0"
            dhcp      = true
            vip = var.enable_floating_ip ? {
              ip = data.hcloud_floating_ip.control_plane_ipv4[0].ip_address
              hcloud = {
                apiToken = var.hcloud_token
              }
            } : null
          },
          {
            interface = "eth1"
            dhcp      = true
            vip = var.enable_alias_ip ? {
              ip = local.control_plane_private_vip_ipv4
              hcloud = {
                apiToken = var.hcloud_token
              }
            } : null
          }
        ]
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
        kubernetesTalosAPIAccess = {
          enabled = true
          allowedRoles = [
            "os:reader"
          ]
          allowedKubernetesNamespaces = [
            "kube-system"
          ]
        }
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
      allowSchedulingOnControlPlanes = var.allow_scheduling_on_control_planes
      network = {
        dnsDomain = var.cluster_domain
        podSubnets = [
          var.pod_ipv4_cidr
        ]
        serviceSubnets = [
          var.service_ipv4_cidr
        ]
        cni = {
          name = "none"
        }
      }
      coreDNS = {
        disabled = var.disable_talos_coredns
      }
      proxy = {
        disabled = true
      }
      apiServer = {
        certSANs  = local.cert_SANs
        extraArgs = var.kube_api_extra_args
      }
      controllerManager = {
        extraArgs = {
          "cloud-provider"           = "external"
          "node-cidr-mask-size-ipv4" = local.node_ipv4_cidr_mask_size
          "bind-address" : "0.0.0.0"
        }
      }
      etcd = {
        advertisedSubnets = [
          var.node_ipv4_cidr
        ]
        extraArgs = {
          "listen-metrics-urls" = "http://0.0.0.0:2381"
        }
      }
      scheduler = {
        extraArgs = {
          "bind-address" = "0.0.0.0"
        }
      }
      extraManifests = var.extraManifests
      inlineManifests = [
        {
          name = "hcloud-secret"
          contents = replace(yamlencode({
            apiVersion = "v1"
            kind       = "Secret"
            type       = "Opaque"
            metadata = {
              name      = "hcloud"
              namespace = "kube-system"
            }
            data = {
              network = base64encode(hcloud_network.this.id)
              token   = base64encode(var.hcloud_token)
            }
          }), "\"", "")
        }
      ]
      externalCloudProvider = {
        enabled = true
        manifests = [
          "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/v1.6.0/docs/deploy/cloud-controller-manager-daemonset.yml"
        ]
      }
    }
  }

  control_planes = {
    for flat_index, item in flatten([
      for name, cfg in var.control_planes : [
        for i in range(cfg.count) : {
          key  = "${name}-${i}"
          name = "${local.cluster_prefix}${name}-${i + 1}"
          cfg  = cfg
        }
      ]
      ]) : item.key => {
      index           = flat_index
      name            = item.name
      extra_user_data = item.cfg.extra_user_data
      server_type     = item.cfg.server_type
      datacenter      = item.cfg.datacenter
      ipv4_enabled    = item.cfg.ipv4_enabled
      ipv6_enabled    = item.cfg.ipv6_enabled
      image           = substr(item.cfg.server_type, 0, 3) == "cax" ? (var.disable_arm ? null : data.hcloud_image.arm[0].id) : (var.disable_x86 ? null : data.hcloud_image.x86[0].id)
      labels = merge(item.cfg.labels, {
        cluster = var.cluster_name,
        role    = "control-plane"
      })
    }
  }
}

resource "hcloud_placement_group" "control_plane" {
  name = "${local.cluster_prefix}control-plane"
  type = "spread"
  labels = {
    "cluster" = var.cluster_name
  }
}


data "talos_machine_configuration" "control_plane" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [yamlencode(local.controlplane_yaml), yamlencode(each.value.extra_user_data)]
  docs               = false
  examples           = false
}

resource "hcloud_server" "control_planes" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  datacenter         = each.value.datacenter
  name               = each.value.name
  image              = each.value.image
  server_type        = each.value.server_type
  user_data          = data.talos_machine_configuration.control_plane[each.value.name].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.control_plane.id

  labels = each.value.labels

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = each.value.ipv4_enabled
    ipv4         = each.value.ipv4_enabled ? hcloud_primary_ip.control_plane_ipv4[each.key].id : null
    ipv6_enabled = each.value.ipv6_enabled
    ipv6         = each.value.ipv6_enabled ? hcloud_primary_ip.control_plane_ipv6[each.key].id : null
  }

  network {
    network_id = hcloud_network_subnet.nodes.network_id
    ip         = local.control_plane_private_ipv4_list[each.value.index]
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


