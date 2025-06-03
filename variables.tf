# General
variable "hcloud_token" {
  type        = string
  description = "The Hetzner Cloud API token."
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}

variable "cluster_domain" {
  type        = string
  default     = "cluster.local"
  description = "The domain name of the cluster."
}

variable "cluster_prefix" {
  type        = bool
  default     = false
  description = "Prefix Hetzner Cloud resources with the cluster name."
}

variable "cluster_api_host" {
  type        = string
  description = <<EOF
    Optional. A stable DNS hostname for the public Kubernetes API endpoint (e.g., `kube.mydomain.com`).
    If set, you MUST configure a DNS A record for this hostname pointing to your desired public entrypoint (e.g., Floating IP, Load Balancer IP).
    This hostname will be embedded in the cluster's certificates (SANs).
    If not set, the generated kubeconfig/talosconfig will use an IP address based on `output_mode_config_cluster_endpoint`.
    Internal cluster communication often uses `kube.[cluster_domain]`, which is handled automatically via /etc/hosts if `enable_alias_ip = true`.
  EOF
  default     = null
}

variable "datacenter" {
  type        = string
  description = <<EOF
    The name of the datacenter where the cluster will be created.
    This is used to determine the region and zone of the cluster and network.
    Possible values: fsn1-dc14, nbg1-dc3, hel1-dc2, ash-dc1, hil-dc1
  EOF
  validation {
    condition     = contains(["fsn1-dc14", "nbg1-dc3", "hel1-dc2", "ash-dc1", "hil-dc1"], var.datacenter)
    error_message = "Invalid datacenter name."
  }
}

variable "output_mode_config_cluster_endpoint" {
  type    = string
  default = "public_ip"
  validation {
    condition     = contains(["public_ip", "private_ip", "cluster_endpoint"], var.output_mode_config_cluster_endpoint)
    error_message = "Invalid output mode for kube and talos config endpoint."
  }
  description = <<EOF
    Configure which endpoint address is written into the generated `talosconfig` and `kubeconfig` files.
    - `public_ip`: Use the public IP of the first control plane (or the Floating IP if enabled).
    - `private_ip`: Use the private IP of the first control plane (or the private Alias IP if enabled). Useful if accessing only via VPN/private network.
    - `cluster_endpoint`: Use the hostname defined in `cluster_api_host`. Requires `cluster_api_host` to be set.
  EOF
}

# Network

variable "enable_ipv6" {
  type        = bool
  default     = false
  description = <<EOF
    If true, the servers will have an IPv6 address.
    IPv4/IPv6 dual-stack is actually not supported, it keeps being an IPv4 single stack. PRs welcome!
  EOF
}

variable "enable_kube_span" {
  type        = bool
  default     = false
  description = "If true, the KubeSpan Feature (with \"Kubernetes registry\" mode) will be enabled."
}


# Server
variable "talos_version" {
  type        = string
  description = "The version of talos features to use in generated machine configurations."
}

variable "disable_x86" {
  type        = bool
  default     = false
  description = "If true, x86 images will not be used."
}

variable "disable_arm" {
  type        = bool
  default     = false
  description = "If true, arm images will not be used."
}

# Talos
variable "kubelet_extra_args" {
  type        = map(string)
  default     = {}
  description = "Additional arguments to pass to kubelet."
}

variable "kube_api_extra_args" {
  type        = map(string)
  default     = {}
  description = "Additional arguments to pass to the kube-apiserver."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.30.3"
  description = <<EOF
    The Kubernetes version to use. If not set, the latest version supported by Talos is used: https://www.talos.dev/v1.7/introduction/support-matrix/
    Needs to be compatible with the `cilium_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
  EOF
}

variable "sysctls_extra_args" {
  type        = map(string)
  default     = {}
  description = "Additional sysctls to set."
}

variable "kernel_modules_to_load" {
  type = list(object({
    name       = string
    parameters = optional(list(string))
  }))
  default     = null
  description = "List of kernel modules to load."
}

variable "registries" {
  type = object({
    mirrors = optional(map(object({
      endpoints    = list(string)
      overridePath = optional(bool)
    })))
    config = optional(map(object({
      auth = object({
        username      = optional(string)
        password      = optional(string)
        auth          = optional(string)
        identityToken = optional(string)
      })
    })))
  })
  default     = null
  description = <<EOF
    List of registry mirrors to use.
    Example:
    ```
    registries = {
      mirrors = {
        "docker.io" = {
          endpoints = [
            "http://localhost:5000",
            "https://docker.io"
          ]
        }
      }
    }
    ```
    https://www.talos.dev/v1.6/reference/configuration/v1alpha1/config/#Config.machine.registries
  EOF
}

# Deployments


variable "disable_talos_coredns" {
  type        = bool
  default     = false
  description = "If true, the CoreDNS delivered by Talos will not be deployed."
}

variable "extraManifests" {
  type        = list(string)
  default     = null
  description = "Additional manifests URL applied during Talos bootstrap."
}
