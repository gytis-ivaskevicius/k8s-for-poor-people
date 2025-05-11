variable "autoscaler_nodepools" {
  description = "Cluster autoscaler nodepools."
  type = list(object({
    name          = string
    instance_type = string
    region        = string
    min_nodes     = number
    max_nodes     = number
    labels        = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = []
}


locals {

  cluster_config = {
    imagesForArch = {
      arm64 = var.disable_arm ? null : tostring(data.hcloud_image.arm[0].id)
      amd64 = var.disable_x86 ? null : tostring(data.hcloud_image.x86[0].id)
    }
    nodeConfigs = {
      for index, nodePool in var.autoscaler_nodepools :
      (nodePool.name) => {
        cloudInit = data.talos_machine_configuration.autoscaler.machine_configuration
        labels    = nodePool.labels
        taints    = nodePool.taints
      }
    }
  }
}

data "talos_machine_configuration" "autoscaler" {
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = concat([yamlencode(local.worker_yaml)], var.talos_worker_extra_config_patches)
  docs               = false
  examples           = false
}

resource "kubernetes_secret" "hetzner_api_token" {
  metadata {
    name      = "hetzner-api-token"
    namespace = "kube-system"
  }

  data = {
    token = var.hcloud_token
  }
}

resource "helm_release" "autoscaler" {
  name = "autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.46.6"

  values = [yamlencode({
    cloudProvider = "hetzner"
    autoDiscovery = {
      clusterName = var.cluster_name
    }

    extraEnvSecrets = {
      HCLOUD_TOKEN = {
        name = "hetzner-api-token"
        key  = "token"
      }
    }

    extraEnv = {
      HCLOUD_FIREWALL       = tostring(hcloud_firewall.this.id)
      HCLOUD_NETWORK        = tostring(hcloud_network_subnet.nodes.network_id)
      HCLOUD_CLUSTER_CONFIG = base64encode(jsonencode(local.cluster_config))
    }

    autoscalingGroups = [
      for np in var.autoscaler_nodepools : {
        name         = np.name
        maxSize      = np.max_nodes
        minSize      = np.min_nodes
        instanceType = np.instance_type
        region       = np.region
      }
    ]
  })]
}


