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

variable "chart_version" {
  type        = string
  default     = null
  description = "The Traefik version to use."
}

variable "enable_dashboard" {
  type        = bool
  default     = false
  description = "If true, the Traefik dashboard will be enabled."
}

variable "values" {
  type        = map(any)
  default     = {}
  description = "Additional values to pass to the chart."
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.chart_version

  values = [
    yamlencode(merge({

      ports = {
        web = {
          port     = 80
            #redirections = {
            #  entryPoint = {
            #    to        = "websecure"
            #    scheme    = "https"
            #    permanent = true
            #  }
            #}
        }
        websecure = {
          port     = 443
        }
      }

      service = {
        annotations = {
          "load-balancer.hetzner.cloud/location" = "fsn1"
        }
        ports = {
          web = {
            port = 80
          }
          websecure = {
            port = 443
          }
        }
      }

      api = {
        dashboard = true
      }


      ingressRoute = {
        dashboard = {
          enabled = var.enable_dashboard
        }
      }

      securityContext = {
        capabilities = {
          drop = ["ALL"]
          add  = ["NET_BIND_SERVICE"]
        }
        readOnlyRootFilesystem = true
        runAsGroup             = 0
        runAsNonRoot           = false
        runAsUser              = 0
      }

      persistence = {
        enabled = false
      }

      certificatesResolvers = {
        le = {
          acme = {
            email        = "me@gytis.io"
            storage      = "/data/acme.json"
            httpChallenge = {
              entrypoint = "web"
            }
          }
        }
      }

      #additionalArguments = [
      #  "--providers.kubernetescrd.allowCrossNamespace=true"
      #]

      #priorityClassName = "system-cluster-critical"

      #globalArguments = [
      #  "--global.sendanonymoususage=false",
      #  "--global.checknewversion=false"
      #]
    }, var.values))
  ]
}

