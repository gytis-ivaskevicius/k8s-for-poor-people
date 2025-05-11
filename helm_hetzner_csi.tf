variable "hcloud_csi" {
  description = "Hetzner Cloud CSI"
  type = object({
    enabled = optional(bool, true)
    version = optional(string, null)
    values  = optional(map(any))
  })
  default = {}
}

resource "helm_release" "hcloud_csi" {
  count      = var.hcloud_csi.enabled ? 1 : 0
  name       = "hcloud-csi"
  namespace  = "kube-system"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-csi"
  version    = var.hcloud_csi.version
  values     = [yamlencode(var.hcloud_csi.values)]
}

