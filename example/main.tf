
variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "hcloud_token" {
  description = "The hcloud token to use for the hcloud provider"
  type        = string
  sensitive   = true
}

provider "kubernetes" {
  host                   = module.talos.kubeconfig_data.host
  cluster_ca_certificate = module.talos.kubeconfig_data.cluster_ca_certificate
  client_certificate     = module.talos.kubeconfig_data.client_certificate
  client_key             = module.talos.kubeconfig_data.client_key
}

provider "helm" {
  kubernetes {
    host                   = module.talos.kubeconfig_data.host
    client_certificate     = module.talos.kubeconfig_data.client_certificate
    client_key             = module.talos.kubeconfig_data.client_key
    cluster_ca_certificate = module.talos.kubeconfig_data.cluster_ca_certificate
  }
}

locals {
  allowed_ips = [
    "0.0.0.0/0",
    "::/0"
  ]
}

module "talos" {
  source = "../"
  #source  = "hcloud-talos/talos/hcloud"
  #version = "2.15.1" # Replace with the latest version number
  talos_version = "v1.9.5" # The version of talos features to use in generated machine configurations

  hcloud_token              = var.hcloud_token
  firewall_kube_api_source  = local.allowed_ips
  firewall_talos_api_source = local.allowed_ips

  cluster_name = "poor-people-cluster"

  # $ hcloud datacenter list
  datacenter_name = "fsn1-dc14"

  cilium = {
    version = "v1.17.3"
  }

  control_planes = {
    control-plane = {
      server_type = "cx32"
      datacenter  = "fsn1-dc14"
    }
  }

  autoscaler_nodepools = {
    autoscaler = {
      server_type = "cpx11"
      min_nodes   = 0
      max_nodes   = 1
      datacenter  = "fsn1"
    }
  }
}

module "ingress" {
  source               = "../batteries/cloudflare-ingress"
  cloudflare_api_token = var.cloudflare_api_token
  external_dns = {
    domain_filters = ["gytis.place"]
  }
  traefik = {
    dashboard_domain = "traefik.gytis.place"
    acme_email       = "me@gytis.io"
    lb_datacenter    = "fsn1"
    enable_dashboard = true
  }
}

output "talosconfig" {
  value     = module.talos.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}
