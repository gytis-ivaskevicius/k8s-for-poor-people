<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_traefik"></a> [traefik](#module\_traefik) | ../traefik | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.external_dns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret.external_dns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token | `string` | n/a | yes |
| <a name="input_external_dns"></a> [external\_dns](#input\_external\_dns) | ExternalDNS configuration | <pre>object({<br/>    version        = optional(string, null)<br/>    values         = optional(map(any))<br/>    namespace      = optional(string, "kube-system")<br/>    domain_filters = optional(list(string), [])<br/>    txt_owner_id   = optional(string, "external-dns")<br/>  })</pre> | `{}` | no |
| <a name="input_traefik"></a> [traefik](#input\_traefik) | Traefik configuration | <pre>object({<br/>    version          = optional(string, null)<br/>    values           = optional(map(any))<br/>    namespace        = optional(string, "traefik")<br/>    enable_dashboard = optional(bool, false)<br/>    lb_datacenter    = string<br/>    acme_email       = string<br/>  })</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->