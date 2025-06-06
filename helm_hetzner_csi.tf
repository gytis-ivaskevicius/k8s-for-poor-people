variable "hcloud_csi" {
  description = "Hetzner Cloud CSI"
  type = object({
    enabled   = optional(bool, true)
    version   = optional(string, null)
    values    = optional(map(any))
    namespace = optional(string, "kube-system")
  })
  default = {}
}

resource "helm_release" "hcloud_csi" {
  count      = var.hcloud_csi.enabled ? 1 : 0
  name       = "hcloud-csi"
  namespace  = var.hcloud_csi.namespace
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-csi"
  version    = var.hcloud_csi.version
  values     = [yamlencode(var.hcloud_csi.values)]
  depends_on = [data.http.talos_health, helm_release.cilium]
}

