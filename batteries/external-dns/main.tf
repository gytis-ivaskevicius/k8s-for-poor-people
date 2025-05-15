
variable "chart_version" {
  description = "Version of ExternalDNS"
  type        = string
  default     = null
}

variable "values" {
  description = "Additional values for ExternalDNS"
  type        = any
  default     = {}
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "The namespace to deploy ExternalDNS into."
}


resource "helm_release" "external_dns" {
  name      = "external-dns"
  namespace = var.namespace

  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version

  values = [yamlencode(var.values)]
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}
