resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

locals {
  api_port_k8s        = 6443
  api_port_kube_prism = 7445

  best_public_ipv4 = (
    var.enable_floating_ip ?
    # Use floating IP
    data.hcloud_floating_ip.control_plane_ipv4[0].ip_address :
    # Use first public IP
    can(local.control_plane_public_ipv4_list[0]) ? local.control_plane_public_ipv4_list[0] : "unknown"
  )

  best_private_ipv4 = (
    var.enable_alias_ip ?
    # Use alias IP
    local.control_plane_private_vip_ipv4 :
    # Use first private IP
    local.control_plane_private_ipv4_list[0]
  )

  cluster_api_host_private = "kube.${var.cluster_domain}"
  cluster_api_host_public  = var.cluster_api_host != null ? var.cluster_api_host : local.best_public_ipv4

  # Use the best option available for the cluster endpoint
  # cluster_api_host_private (alias IP) > cluster_api_host > floating IP > first private IP
  cluster_endpoint_internal = var.enable_alias_ip ? local.cluster_api_host_private : (
    var.cluster_api_host != null ? var.cluster_api_host : (
      var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address :
      local.control_plane_private_ipv4_list[0]
    )
  )
  cluster_endpoint_url_internal = "https://${local.cluster_endpoint_internal}:${local.api_port_k8s}"

  // ************
  cert_SANs = distinct(
    concat(
      local.control_plane_public_ipv4_list,
      local.control_plane_public_ipv6_list,
      local.control_plane_private_ipv4_list,
      compact([
        local.cluster_api_host_private,
        local.cluster_api_host_public,
        var.enable_alias_ip ? local.control_plane_private_vip_ipv4 : null,
        var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : null,
      ])
    )
  )

  extra_host_entries = var.enable_alias_ip ? [
    {
      ip = local.control_plane_private_vip_ipv4
      aliases = [
        local.cluster_api_host_private
      ]
    }
  ] : []
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.control_plane_public_ipv4_list[0]
  node                 = local.control_plane_public_ipv4_list[0]
  depends_on = [
    hcloud_server.control_planes
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = compact(
    var.output_mode_config_cluster_endpoint == "private_ip" ? (
      # Use private IPs in talosconfig
      local.control_plane_private_ipv4_list
    ) :

    var.output_mode_config_cluster_endpoint == "public_ip" ? (
      # Use public IPs in talosconfig
      local.control_plane_public_ipv4_list
    ) :

    var.output_mode_config_cluster_endpoint == "cluster_endpoint" ? (
      # Use cluster endpoint in talosconfig
      [local.cluster_api_host_public]
    ) : []
  )
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_public_ipv4_list[0]
  depends_on = [
    talos_machine_bootstrap.this
  ]
}

locals {
  kubeconfig_host = (
    var.output_mode_config_cluster_endpoint == "private_ip" ? local.best_private_ipv4 :
    var.output_mode_config_cluster_endpoint == "public_ip" ? local.best_public_ipv4 :
    var.output_mode_config_cluster_endpoint == "cluster_endpoint" ? local.cluster_api_host_public :
    "unknown"
  )
  kubeconfig = replace(
    can(talos_cluster_kubeconfig.this.kubeconfig_raw) ? talos_cluster_kubeconfig.this.kubeconfig_raw : "",
    local.cluster_endpoint_url_internal, "https://${local.kubeconfig_host}:${local.api_port_k8s}"
  )

  kubeconfig_data = {
    host                   = "https://${local.best_public_ipv4}:${local.api_port_k8s}"
    cluster_name           = var.cluster_name
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }
}
