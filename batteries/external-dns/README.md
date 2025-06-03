# ExternalDNS Terraform Module

This Terraform module deploys ExternalDNS in your Kubernetes cluster using Helm. It allows you to customize the deployment with specific chart versions, namespace, and additional values.

## Usage

```hcl
module "external_dns" {
  source       = "<path-to-this-module>"
  chart_version = "1.3.0"
  values        = {
    # your custom values here
  }
  namespace     = "kube-system"
}


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.external_dns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of ExternalDNS | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to deploy ExternalDNS into. | `string` | `"kube-system"` | no |
| <a name="input_values"></a> [values](#input\_values) | Additional values for ExternalDNS | `any` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
