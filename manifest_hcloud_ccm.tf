variable "hcloud_ccm" {
  description = "Hetzner Cloud Controller Manager"
  type = object({
    enabled   = optional(bool, true)
    version   = optional(string, null)
    values    = optional(map(any))
    namespace = optional(string, "kube-system")
  })
  default = {}
}

resource "helm_release" "hcloud_ccm" {
  count            = var.hcloud_ccm.enabled ? 1 : 0
  name             = "hcloud-cloud-controller-manager"
  repository       = "https://charts.hetzner.cloud"
  chart            = "hcloud-cloud-controller-manager"
  version          = var.hcloud_ccm.version
  namespace        = var.hcloud_ccm.namespace
  create_namespace = true


  values = [yamlencode(merge({
    networking = {
      enabled     = true
      clusterCIDR = var.pod_ipv4_cidr
    }
    env = {
      HCLOUD_LOAD_BALANCERS_USE_PRIVATE_IP = {
        value = "true"
      }
      HCLOUD_LOAD_BALANCERS_ENABLED = {
        value = "true"
      }
      HCLOUD_LOAD_BALANCERS_DISABLE_PRIVATE_INGRESS = {
        value = "true"
      }
    }
  }, var.hcloud_ccm.values))]

  depends_on = [data.http.talos_health, helm_release.cilium]
}

