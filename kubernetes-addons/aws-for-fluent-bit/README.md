# aws-for-fluent-bit Helm Chart
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.eks_worker_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [helm_release.aws_for_fluent_bit](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_for_fluent_bit_helm_chart"></a> [aws\_for\_fluent\_bit\_helm\_chart](#input\_aws\_for\_fluent\_bit\_helm\_chart) | n/a | `any` | `{}` | no |
| <a name="input_cw_worker_loggroup_name"></a> [cw\_worker\_loggroup\_name](#input\_cw\_worker\_loggroup\_name) | n/a | `string` | n/a | yes |
| <a name="input_ekslog_retention_in_days"></a> [ekslog\_retention\_in\_days](#input\_ekslog\_retention\_in\_days) | n/a | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cw_loggroup_arn"></a> [cw\_loggroup\_arn](#output\_cw\_loggroup\_arn) | EKS Cloudwatch group arn |
| <a name="output_cw_loggroup_name"></a> [cw\_loggroup\_name](#output\_cw\_loggroup\_name) | EKS Cloudwatch group Name |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
