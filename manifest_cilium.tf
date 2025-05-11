variable "cilium" {
  description = "Cilium configuration. Service Monitor requires monitoring.coreos.com/v1 CRDs."
  type = object({
    enabled                 = optional(bool, true)
    version                 = optional(string, null)
    values                  = optional(map(any))
    enable_encryption       = optional(bool, false)
    enable_service_monitors = optional(bool, false)
  })
  default = {}
}

variable "deploy_prometheus_operator_crds" {
  type        = bool
  default     = false
  description = "If true, the Prometheus Operator CRDs will be deployed."
}

resource "helm_release" "cilium" {
  count     = var.cilium.enabled ? 1 : 0
  name      = "cilium"
  namespace = "kube-system"

  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium.version


  values = [yamlencode(merge({
    operator = {
      replicas = length(var.control_planes) > 1 ? 2 : 1
      prometheus = {
        serviceMonitor = {
          enabled = var.cilium.enable_service_monitors
        }
      }
    }
    ipam = {
      mode = "kubernetes"
    }
    routingMode           = "native"
    ipv4NativeRoutingCIDR = var.pod_ipv4_cidr
    kubeProxyReplacement  = "true"
    bpf = {
      masquerade = false
    }
    loadBalancer = {
      acceleration = "native"
    }
    encryption = {
      enabled = var.cilium.enable_encryption
      type    = "wireguard"
    }
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
    cgroup = {
      autoMount = {
        enabled = false
      }
      hostRoot = "/sys/fs/cgroup"
    }
    k8sServiceHost = "127.0.0.1"
    k8sServicePort = local.api_port_kube_prism
    hubble = {
      enabled = false
    }
    prometheus = {
      serviceMonitor = {
        enabled        = var.cilium.enable_service_monitors
        trustCRDsExist = var.cilium.enable_service_monitors
      }
    }
  }, var.cilium.values))]
}


resource "helm_release" "prometheus_operator_crds" {
  count      = var.deploy_prometheus_operator_crds ? 1 : 0
  chart      = "prometheus-operator-crds"
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
}
