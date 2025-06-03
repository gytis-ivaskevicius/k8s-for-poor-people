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

variable "chart_version" {
  type        = string
  default     = null
  description = "The Traefik version to use."
}

variable "enable_dashboard" {
  type        = bool
  default     = true
  description = "If true, the Traefik dashboard will be enabled."
}

variable "values" {
  type        = map(any)
  default     = {}
  description = "Additional values to pass to the chart."
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token"
}

variable "lb_datacenter" {
  type        = string
  description = "The datacenter of the load balancer"
}

variable "acme_email" {
  type        = string
  description = "The email to use for Let's Encrypt"
}

variable "namespace" {
  type        = string
  default     = "traefik"
  description = "The namespace to deploy Traefik into."
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version

  values = [
    yamlencode(merge({
      deployment = {
        strategy = {
          type = "Recreate"
        }
      }

      service = {
        annotations = {
          "load-balancer.hetzner.cloud/location" = var.lb_datacenter
        }
      }

      api = {
        dashboard = var.enable_dashboard
      }


      ingressRoute = {
        dashboard = {
          enabled = var.enable_dashboard
        }
      }

      envFrom = [
        {
          name = "CF_DNS_API_TOKEN"
          secretRef = {
            name = "cloudflare"
            key  = "token"
          }
        }
      ]


      securityContext = {
        capabilities = {
          add = ["NET_BIND_SERVICE"]
        }
        runAsNonRoot = false
        runAsGroup   = 0
        runAsUser    = 0
      }

      persistence = {
        enabled      = true
        storageClass = "hcloud-volumes"
        accessMode   = "ReadWriteOnce"
        size         = "1Gi"
      }

      certificatesResolvers = {
        le = {
          acme = {
            email   = var.acme_email
            storage = "/data/acme.json"
            dnsChallenge = {
              provider = "cloudflare"
            }
          }
        }
      }

      globalArguments = [
        "--global.sendanonymoususage=false",
        "--global.checknewversion=false"
      ]
    }, var.values))
  ]
}

resource "kubernetes_secret" "cloudflare" {
  metadata {
    name      = "cloudflare"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    CF_DNS_API_TOKEN = var.cloudflare_api_token
  }
}

