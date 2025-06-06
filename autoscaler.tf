
variable "autoscaler_nodepools" {
  description = "Workers definition. K8s autoscaler will be installed if this map has at least one entry"
  type = map(object({
    server_type     = string
    min_nodes       = number
    max_nodes       = number
    datacenter      = optional(string)
    extra_user_data = optional(map(any))
    labels          = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {}
}

variable "autoscaler_version" {
  type        = string
  default     = null
  description = "Version of the autoscaler to use. Default is the latest version."
}


locals {
  cluster_config = {
    imagesForArch = {
      arm64 = var.disable_arm ? null : tostring(data.hcloud_image.arm[0].id)
      amd64 = var.disable_x86 ? null : tostring(data.hcloud_image.x86[0].id)
    }
    nodeConfigs = {
      for np_name, np in var.autoscaler_nodepools :
      np_name => {
        cloudInit = data.talos_machine_configuration.autoscaler[np_name].machine_configuration
        labels    = np.labels
        taints    = np.taints
      }
    }
  }
}

data "talos_machine_configuration" "autoscaler" {
  for_each = var.autoscaler_nodepools

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [yamlencode(local.worker_yaml), yamlencode(each.value.extra_user_data)]
  docs               = false
  examples           = false
}

resource "helm_release" "autoscaler" {
  count = length(var.autoscaler_nodepools) > 0 ? 1 : 0
  name  = "hetzner-cluster-autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.autoscaler_version
  depends_on = [data.http.talos_health, helm_release.cilium]

  values = [yamlencode({
    cloudProvider = "hetzner"
    autoDiscovery = {
      clusterName = var.cluster_name
    }

    extraEnvSecrets = {
      HCLOUD_TOKEN = {
        name      = "hcloud"
        namespace = "kube-system"
        key       = "token"
      }
    }

    extraEnv = {
      HCLOUD_FIREWALL       = tostring(hcloud_firewall.this.id)
      HCLOUD_NETWORK        = tostring(hcloud_network_subnet.nodes.network_id)
      HCLOUD_CLUSTER_CONFIG = base64encode(jsonencode(local.cluster_config))
    }


    autoscalingGroups = [
      for np_name, np in var.autoscaler_nodepools : {
        name         = "${local.cluster_prefix}${np_name}"
        maxSize      = np.max_nodes
        minSize      = np.min_nodes
        instanceType = np.server_type
        region       = coalesce(np.datacenter, var.datacenter)
      }
    ]
  })]
}


