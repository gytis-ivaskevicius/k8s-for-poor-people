variable "cilium_version" {
  type        = string
  default     = "1.16.2"
  description = <<EOF
    The version of Cilium to deploy. If not set, the `1.16.0` version will be used.
    Needs to be compatible with the `kubernetes_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
  EOF
}

variable "cilium_values" {
  type        = list(string)
  default     = null
  description = <<EOF
    The values.yaml file to use for the Cilium Helm chart.
    If null (default), the default values will be used.
    Otherwise, the provided values will be used.
    Example:
    ```
    cilium_values  = [templatefile("cilium/values.yaml", {})]
    ```
  EOF
}

variable "cilium_enable_encryption" {
  type        = bool
  default     = false
  description = "Enable transparent network encryption."
}

variable "cilium_enable_service_monitors" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the service monitors for Prometheus will be enabled.
    Service Monitor requires monitoring.coreos.com/v1 CRDs.
    You can use the deploy_prometheus_operator_crds variable to deploy them.
  EOF
}

variable "deploy_prometheus_operator_crds" {
  type        = bool
  default     = false
  description = "If true, the Prometheus Operator CRDs will be deployed."
}


data "helm_template" "cilium_default" {
  count     = var.cilium_values == null ? 1 : 0
  name      = "cilium"
  namespace = "kube-system"

  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  set {
    name  = "operator.replicas"
    value = length(var.control_planes) > 1 ? 2 : 1
  }
  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }
  set {
    name  = "routingMode"
    value = "native"
  }
  set {
    name  = "ipv4NativeRoutingCIDR"
    value = var.pod_ipv4_cidr
  }
  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
  set {
    name  = "bpf.masquerade"
    value = "false"
  }
  set {
    name  = "loadBalancer.acceleration"
    value = "native"
  }
  set {
    name  = "encryption.enabled"
    value = var.cilium_enable_encryption ? "true" : "false"
  }
  set {
    name  = "encryption.type"
    value = "wireguard"
  }
  set {
    name  = "securityContext.capabilities.ciliumAgent"
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }
  set {
    name  = "securityContext.capabilities.cleanCiliumState"
    value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }
  set {
    name  = "cgroup.autoMount.enabled"
    value = "false"
  }
  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }
  set {
    name  = "k8sServiceHost"
    value = "127.0.0.1"
  }
  set {
    name  = "k8sServicePort"
    value = local.api_port_kube_prism
  }
  set {
    name  = "hubble.enabled"
    value = "false"
  }
  set {
    name  = "prometheus.serviceMonitor.enabled"
    value = var.cilium_enable_service_monitors ? "true" : "false"
  }
  set {
    name  = "prometheus.serviceMonitor.trustCRDsExist"
    value = var.cilium_enable_service_monitors ? "true" : "false"
  }
  set {
    name  = "operator.prometheus.serviceMonitor.enabled"
    value = var.cilium_enable_service_monitors ? "true" : "false"
  }
}

data "helm_template" "cilium_from_values" {
  count     = var.cilium_values != null ? 1 : 0
  name      = "cilium"
  namespace = "kube-system"

  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version
  values       = var.cilium_values
}

data "kubectl_file_documents" "cilium" {
  content = coalesce(
    can(data.helm_template.cilium_from_values[0].manifest) ? data.helm_template.cilium_from_values[0].manifest : null,
    can(data.helm_template.cilium_default[0].manifest) ? data.helm_template.cilium_default[0].manifest : null
  )
}

resource "kubectl_manifest" "apply_cilium" {
  for_each   = data.kubectl_file_documents.cilium.manifests
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health]
}


data "helm_template" "prometheus_operator_crds" {
  count        = var.deploy_prometheus_operator_crds ? 1 : 0
  chart        = "prometheus-operator-crds"
  name         = "prometheus-operator-crds"
  repository   = "https://prometheus-community.github.io/helm-charts"
  kube_version = var.kubernetes_version
}

data "kubectl_file_documents" "prometheus_operator_crds" {
  count   = var.deploy_prometheus_operator_crds ? 1 : 0
  content = data.helm_template.prometheus_operator_crds[0].manifest
}

resource "kubectl_manifest" "apply_prometheus_operator_crds" {
  for_each          = var.deploy_prometheus_operator_crds ? data.kubectl_file_documents.prometheus_operator_crds[0].manifests : {}
  yaml_body         = each.value
  server_side_apply = true
  apply_only        = true
  depends_on        = [data.http.talos_health]
}
