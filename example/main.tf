
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
  ####################################################
  # Required values:                                 #
  ####################################################
  source = "../"
  #source  = "hcloud-talos/talos/hcloud"
  #version = "0.0.1" # Replace with the latest version number

  hcloud_token = var.hcloud_token
  cluster_name = "poor-people-cluster"

  # The version of talos features to use in generated machine configurations
  talos_version = "v1.9.5"

  # $ hcloud datacenter list
  datacenter = "fsn1-dc14"

  ####################################################
  # Optional values:                                 #
  ####################################################

  # If true, the control plane nodes will be allowed to schedule pods
  allow_scheduling_on_control_planes = true

  # Autoscaler configuration. If used, I strongly recommend pinning autoscaler to a specific version
  autoscaler_version = "9.46.6"

  # Autoscaler configuration. K8s autoscaler will be installed if this map has at least one entry
  autoscaler_nodepools = {
    autoscaler = {
      server_type     = "cpx11"
      datacenter      = "fsn1"
      min_nodes       = 0
      max_nodes       = 1
      extra_user_data = null
      labels = {
        environment = "production"
      }
      taints = [
        {
          key    = "something"
          value  = "abc"
          effect = "PreferNoSchedule"
        }
      ]
    }
  }

  # Cilium configuration. I strongly recommend pinning cilium to a specific version
  cilium = {
    enabled                 = true
    version                 = "1.17.3"
    values                  = {}
    enable_encryption       = false
    enable_service_monitors = false
  }

  # Defines an optional DNS hostname for the Kubernetes API endpoint.
  # If provided, set up a DNS A record pointing to the desired public IP.
  # The hostname will be included in the cluster's certificates (SANs).
  # If not provided, the cluster will use an IP address for the endpoint.
  # Internal communication may use kube.[cluster_domain], managed via /etc/hosts if enable_alias_ip = true.
  cluster_api_host = null

  # The domain name of the cluster.
  cluster_domain = "cluster.local"

  # Prefix Hetzner Cloud resources with the cluster name.
  cluster_prefix = false

  # Control planes definition. Total control_planes count should be 1, 3 or 5
  control_planes = {
    control-plane = {
      server_type     = "cx32"
      datacenter      = "fsn1-dc14"
      count           = 1
      extra_user_data = null
      labels = {
        environment = "production"
      }
      # TODO: Add taints support
      #taints = [
      #  {
      #    key = "something"
      #    value = "abc"
      #    effect = "PreferNoSchedule"
      #  }
      #]
    }
  }

  # If true, the Prometheus Operator CRDs will be deployed.
  deploy_prometheus_operator_crds = false

  # If true, arm/x86 images will not be used
  disable_arm = false
  disable_x86 = false

  # If true, the CoreDNS delivered by Talos will not be deployed.
  disable_talos_coredns = false

  # enable_alias_ip If true, a private alias IP (defaulting to the .100 address within node_ipv4_cidr) will be configured on the control plane nodes.
  # This enables a stable internal IP for the Kubernetes API server, reachable via kube.[cluster_domain].
  # The module automatically configures /etc/hosts on nodes to resolve kube.[cluster_domain] to this alias IP.
  enable_alias_ip = true

  # Whether to create and assign a floating IP to control plane nodes
  enable_floating_ip = false

  # If true, the servers will have an IPv6 address.
  # IPv4/IPv6 dual-stack is actually not supported, it keeps being an IPv4 single stack. PRs welcome!
  enable_ipv6 = false

  # Enable KubeSpan feature in "Kubernetes registry" mode
  enable_kube_span = false

  # URLs of additional Talos manifests to apply during bootstrap
  extraManifests = [
    #"https://example.com/manifests/0-bootstrap.yaml",
    #"https://example.com/manifests/1-network.yaml",
  ]

  # Extra firewall rules for the cluster
  extra_firewall_rules = [
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "80"
      source_ips  = local.allowed_ips
      description = "Allow HTTP access"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "443"
      source_ips  = local.allowed_ips
      description = "Allow HTTPS access"
    },
  ]

  # CIDR blocks allowed to access the Kubernetes API
  firewall_kube_api_source = local.allowed_ips

  # CIDR blocks allowed to access the Talos API
  firewall_talos_api_source = local.allowed_ips

  # Existing Floating IP ID for control plane (null to create new)
  floating_ip = {
    id = null
  }

  # Hetzner Cloud Controller Manager settings. I strongly recommend pinning hcloud_ccm to a specific version
  hcloud_ccm = {
    enabled   = true
    namespace = "kube-system"
    version   = "1.24.0"
    values    = {}
  }

  # Hetzner Cloud CSI settings. I strongly recommend pinning hcloud_csi to a specific version
  hcloud_csi = {
    enabled   = true
    namespace = "kube-system"
    version   = "2.13.0"
    values    = null
  }

  # Kernel modules to load (name and optional parameters)
  kernel_modules_to_load = [
    #{
    #  name       = "br_netfilter"
    #  parameters = ["nf_call_iframe=1"]
    #},
    #{
    #  name = "ip_vs"
    #},
  ]

  # Extra arguments for kube-apiserver (key = value)
  kube_api_extra_args = {
    #"authorization-mode" = "Node,RBAC"
  }

  # Extra arguments for kubelet (key = value)
  kubelet_extra_args = {
    #"eviction-hard" = "memory.available<100Mi"
  }

  # Kubernetes version (must be compatible with Cilium)
  kubernetes_version = "1.30.3"

  # Main IPv4 CIDR for all subnets
  network_ipv4_cidr = "10.0.0.0/16"

  # IPv4 CIDR for control plane and worker nodes
  node_ipv4_cidr = "10.0.1.0/24"

  # Which endpoint to write into Talos and kubeconfig (public_ip/private_ip/cluster_endpoint)
  output_mode_config_cluster_endpoint = "public_ip"

  # IPv4 CIDR for pods within the cluster
  pod_ipv4_cidr = "10.0.16.0/20"

  # Registry mirror configuration (mirrors and optional auth)
  #registries = {
  #  mirrors = {
  #    "docker.io" = {
  #      endpoints    = ["https://registry.local:5000", "https://docker.io"]
  #      overridePath = true
  #    }
  #  }
  #  config = {
  #    "registry.local" = {
  #      auth = {
  #        username = "admin"
  #        password = "s3cr3t"
  #      }
  #    }
  #  }
  #}

  # IPv4 CIDR for services within the cluster
  service_ipv4_cidr = "10.0.8.0/21"

  # SSH public key to be set on servers.
  # Required to avoid login credential emails from Hetzner.
  ssh_public_key = null

  # Additional sysctls to set on nodes (key = value)
  sysctls_extra_args = {
    #"net.ipv4.ip_forward"                = "1"
    #"net.bridge.bridge-nf-call-iptables" = "1"
  }

  # Worker node definitions. Before defining nodes, consider using autoscaler instead
  workers = {
    #worker-a = {
    #  server_type  = "cx31"
    #  datacenter   = "fsn1-dc14"
    #  labels       = { role = "app" }
    #  count        = 2
    #  extra_user_data = null
    #}
  }

}

module "ingress" {
  source               = "../batteries/cloudflare-ingress"
  cloudflare_api_token = var.cloudflare_api_token
  external_dns = {
    domain_filters = ["gytis.place"]
  }
  traefik = {
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
