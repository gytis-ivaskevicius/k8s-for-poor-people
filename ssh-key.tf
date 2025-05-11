variable "ssh_public_key" {
  description = <<EOF
    The public key to be set in the servers. It is not used in any way.
    If you don't set it, a dummy key will be generated and used.
    Unfortunately, it is still required, otherwise the Hetzner will sen E-Mails with login credentials.
  EOF
  type        = string
  default     = null
  sensitive   = true
}


resource "tls_private_key" "ssh_key" {
  count     = var.ssh_public_key == null ? 1 : 0
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "this" {
  name       = "${local.cluster_prefix}default"
  public_key = coalesce(var.ssh_public_key, can(tls_private_key.ssh_key[0].public_key_openssh) ? tls_private_key.ssh_key[0].public_key_openssh : null)
  labels = {
    "cluster" = var.cluster_name
  }
}
