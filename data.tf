
locals {
  cluster_prefix = var.cluster_prefix ? "${var.cluster_name}-" : ""
}
data "hcloud_image" "arm" {
  count             = var.disable_arm ? 0 : 1
  with_selector     = "os=talos"
  with_architecture = "arm"
  most_recent       = true
}

data "hcloud_image" "x86" {
  count             = var.disable_x86 ? 0 : 1
  with_selector     = "os=talos"
  with_architecture = "x86"
  most_recent       = true
}

