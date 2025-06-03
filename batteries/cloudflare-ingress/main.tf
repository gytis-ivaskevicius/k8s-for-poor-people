
variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "external_dns" {
  description = "ExternalDNS configuration"
  type = object({
    version        = optional(string, null)
    values         = optional(map(any))
    namespace      = optional(string, "kube-system")
    domain_filters = optional(list(string), [])
    txt_owner_id   = optional(string, "external-dns")
  })
  default = {}
}

variable "traefik" {
  description = "Traefik configuration"
  type = object({
    version          = optional(string, null)
    values           = optional(map(any))
    namespace        = optional(string, "traefik")
    enable_dashboard = optional(bool, false)
    lb_datacenter    = string
    acme_email       = string
  })
}

resource "kubernetes_secret" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = var.external_dns.namespace
  }

  data = {
    "cloudflare_api_token" = var.cloudflare_api_token
  }

  type = "kubernetes.io/secret"
}

resource "helm_release" "external_dns" {
  name = "external-dns"

  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = var.external_dns.namespace
  version    = var.external_dns.version

  values = [yamlencode(merge({
    provider = {
      name = "cloudflare"
    }
    interval  = "30s"
    sources   = ["traefik-proxy", "service", "ingress"]
    extraArgs = ["--traefik-disable-legacy"]
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
    domainFilters = var.external_dns.domain_filters
    policy        = "sync"
    txtOwnerId    = var.external_dns.txt_owner_id
  }, var.external_dns.values))]
}

module "traefik" {
  source               = "../traefik"
  cloudflare_api_token = var.cloudflare_api_token
  chart_version        = var.traefik.version
  namespace            = var.traefik.namespace
  enable_dashboard     = var.traefik.enable_dashboard
  values               = var.traefik.values
  lb_datacenter        = var.traefik.lb_datacenter
  acme_email           = var.traefik.acme_email
}

terraform {
  required_version = ">= 1.3.0"

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
