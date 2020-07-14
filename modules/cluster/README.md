# aws-terraform-eks/modules/cluster

This module creates an EKS cluster, associated cluster IAM role, and applies EKS worker policies to the worker node IAM roles.

In order to get a working cluster: manual steps must be performed **after** the cluster is built.  The module will output the required configuration files to enable client and worker node setup and configuration.

## Basic Usage

```
module "eks_cluster" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/cluster/?ref=v0.12.2"

  name               = local.eks_cluster_name
  subnets            = concat(module.vpc.private_subnets, module.vpc.public_subnets) #  Required
  tags               = "${local.tags}"
  worker_roles       = [module.eks_workers.iam_role]
  worker_roles_count = 1
}
```

Full working references are available at [examples](examples)

## Terraform 0.12 upgrade

There should be no changes required to move from previous versions of this module to version 0.12.0 or higher.

## Providers

| Name | Version |
|------|---------|
| aws | >= 2.7.0 |
| null | n/a |
| template | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| alb\_ingress\_controller\_enable | A boolean value that determines if IAM policies related to ALB ingress controller should be created. | `bool` | `true` | no |
| bootstrap\_arguments | Any optional parameters for the EKS Bootstrapping script. This is ignored for all os's except Amazon EKS | `string` | `""` | no |
| bootstrap\_arguments\_windows | Any optional parameters for the EKS Bootstrapping script. This is ignored for all os's except Windows EKS | `string` | `""` | no |
| cluster\_autoscaler\_enable | A boolean value that determines if IAM policies related to cluster autoscaler should be created. | `bool` | `true` | no |
| enabled\_cluster\_log\_types | A list of the desired control plane logging to enable. All logs are enabled by default. | `list(string)` | <pre>[<br>  "api",<br>  "audit",<br>  "authenticator",<br>  "controllerManager",<br>  "scheduler"<br>]</pre> | no |
| environment | Application environment for which this network is being created. Preferred value are Development, Integration, PreProduction, Production, QA, Staging, or Test | `string` | `"Development"` | no |
| kubernetes\_version | The desired Kubernetes version for your cluster. If you do not specify a value here, the latest version available in Amazon EKS is used. | `string` | `""` | no |
| log\_group\_retention | Specifies the number of days you want to retain log events in the specified log group. Possible values are: 0 (Never Expire), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653. | `number` | `0` | no |
| manage\_log\_group | Optionally manage the cluster log group via Terraform. Couple with `log_group_retention` to use a retention other than 'Never Expire'. | `bool` | `false` | no |
| name | The desired name for the EKS cluster. | `string` | n/a | yes |
| security\_groups | Optional list of additional security groups to apply to the EKS Control Plane.  These groups should enable access to the EKS Worker nodes. | `list(string)` | `[]` | no |
| subnets | List of public and private subnets used for the EKS control plane. | `list(string)` | n/a | yes |
| tags | Optional tags to be applied on top of the base tags on all resources | `map(string)` | `{}` | no |
| wait\_for\_cluster | A variable to control whether we pause deployment after creating the EKS cluster to allow time to fully launch. | `bool` | `true` | no |
| worker\_roles | List of IAM roles assigned to worker nodes. | `list(string)` | `[]` | no |
| worker\_roles\_count | The number of worker IAM roles provided. | `number` | `0` | no |

## Outputs

| Name | Description |
|------|-------------|
| aws\_auth\_cm | Contents of the aws-auth-cm.yaml used for cluster configuration.  Value should be retrieved with CLI or SDK to ensure proper formatting |
| certificate\_authority\_data | Assigned CA data for the EKS Cluster |
| cluster\_security\_group\_id | The cluster security group that was created by Amazon EKS for the cluster |
| endpoint | Management endpoint of the EKS Cluster |
| iam\_alb\_ingress | ARN of the EKS Cluster Node ALB Ingress Controller IAM policy |
| iam\_all\_node\_policies | ARN of all EKS Cluster Node IAM polices |
| iam\_autoscaler | ARN of the EKS Cluster Node Cluster Autoscaler IAM policy |
| iam\_cw\_logs | ARN of the EKS Cluster Node Cloudwatch Logs IAM policy |
| identity | Nested attribute containing identity provider information for your cluster. Only available on Kubernetes version 1.13 and 1.14 clusters created or upgraded on or after September 3, 2019. https://www.terraform.io/docs/providers/aws/r/eks_cluster.html#identity |
| kube\_map\_roles | The string value used to configure the cluster with the kubernetes\_config\_map resource |
| kubeconfig | Contents of the kubeconfig file used to connect to the cluster for management.  Value should be retrieved with CLI or SDK to ensure proper formatting |
| name | Assigned name of the EKS Cluster |
| setup | Default EKS bootstrapping script for Linux EC2 instances |
| setup\_windows | Default EKS bootstrapping script for Windows EC2 instances |

