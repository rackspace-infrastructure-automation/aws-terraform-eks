# aws-terraform-eks/modules/kubernetes\_components

This module creates the other required components for EKS to allow additional features like ALB Ingress and Cluster Autoscaler.

## Basic Usage

```
module "eks_config" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/kubernetes_components/?ref=v0.0.5"

  cluster_name    = "${module.eks_cluster.name}"
  kube_map_roles  = "${module.eks_cluster.kube_map_roles}"

}
```

Full working references are available at [examples](examples)

## Providers

| Name | Version |
|------|---------|
| kubernetes | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| alb\_ingress\_controller\_enable | A variable to control whether or not the ALB Ingress resources are enabled | `string` | `true` | no |
| alb\_max\_api\_retries | Maximum number of times to retry the aws calls | `string` | `"10"` | no |
| cluster\_autoscaler\_cpu\_limits | CPU Limits for the CA Pod | `string` | `"100m"` | no |
| cluster\_autoscaler\_cpu\_requests | CPU Requests for the CA Pod | `string` | `"100m"` | no |
| cluster\_autoscaler\_enable | A variable to control whether CA is enabled | `string` | `true` | no |
| cluster\_autoscaler\_mem\_limits | Mem Limits for the CA Pod | `string` | `"300Mi"` | no |
| cluster\_autoscaler\_mem\_requests | Mem requests for the CA Pod | `string` | `"300Mi"` | no |
| cluster\_autoscaler\_scale\_down\_delay | CA Scale down delay | `string` | `"5m"` | no |
| cluster\_autoscaler\_tag\_key | Tag key used with CA. Change this only if you have multiple EKS clusters in the same account. | `string` | `"k8s.io/cluster-autoscaler/enabled"` | no |
| cluster\_name | The name of the EKS Cluster | `string` | n/a | yes |
| kube\_map\_roles | The string used to configure the EKS cluster, retrieved from the EKS Cluster module | `string` | n/a | yes |
| kubernetes\_deployment\_create\_timeout | Timeout for creating instances, replicas, and restoring from Snapshots | `string` | `"30m"` | no |
| kubernetes\_deployment\_delete\_timeout | Timeout for destroying databases. This includes the time required to take snapshots | `string` | `"30m"` | no |
| kubernetes\_deployment\_update\_timeout | Timeout for database modifications | `string` | `"30m"` | no |

## Outputs

No output.

