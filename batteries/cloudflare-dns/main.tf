variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "chart_version" {
  description = "Version of ExternalDNS"
  type        = string
  default     = null
}

variable "domain_filters" {
  description = "List of domain filters for ExternalDNS"
  type        = list(string)
  default     = []
}

variable "values" {
  description = "Additional values for ExternalDNS"
  type        = map(any)
  default     = {}
}

variable "txt_owner_id" {
  type = string
  default = "external-dns"
  description = "The owner ID for TXT records"
}


resource "kubernetes_secret" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"
  }

  data = {
    "cloudflare_api_token" = var.cloudflare_api_token
  }

  type = "kubernetes.io/secret"
}

resource "helm_release" "external_dns" {
  name      = "external-dns"
  namespace = "kube-system"

  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version

  values = [yamlencode(merge({
    provider = {
      name = "cloudflare"
    }
    env = [
      {
        name = "CF_API_TOKEN"
        valueFrom = {
          secretKeyRef = {
            name = "external-dns"
            key  = "cloudflare_api_token"
          }
        }
      }
    ]
    domainFilters = var.domain_filters
    policy        = "sync"
    txtOwnerId    = var.txt_owner_id
  }, var.values))]
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}
