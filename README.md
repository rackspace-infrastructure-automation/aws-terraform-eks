# aws-terraform-eks

This module creates an EKS cluster, associated cluster IAM role, and applies EKS worker policies to the worker node IAM roles.

The module will output the required configuration files to enable client and worker node setup and configuration.

## Basic Usage

```
module "eks_cluster" {
 source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//?ref=v0.0.1"

 name = "${local.eks_cluster_name}"
 subnets = "${concat(module.vpc.private_subnets, module.vpc.public_subnets)}" #  Required
 security_groups = ["${module.sg.eks_control_plane_security_group_id}"]

 worker_roles       = ["${module.eks_workers.iam_role}"]
 worker_roles_count = "1"
}
```

Full working references are available at [examples](examples)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| bootstrap\_arguments | Any optional parameters for the EKS Bootstrapping script. This is ignored for all os's except amazon EKS | string | `""` | no |
| kubernetes\_version | The desired Kubernetes version for your cluster. If you do not specify a value here, the latest version available in Amazon EKS is used. | string | `""` | no |
| name | The desired name for the EKS cluster. | string | n/a | yes |
| security\_groups | List of security groups to apply to the EKS Control Plane.  These groups should enable access to the EKS Worker nodes. | list | n/a | yes |
| subnets | List of public and private subnets used for the EKS control plane. | list | n/a | yes |
| worker\_roles | List of IAM roles assigned to worker nodes. | list | `<list>` | no |
| worker\_roles\_count | The number of worker IAM roles provided. | string | `"0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| aws\_auth\_cm | Contents of the aws-auth-cm.yaml used for cluster configuration.  Value should be retrieved with CLI or SDK to ensure proper formatting |
| certificate\_authority\_data | Assigned CA data for the EKS Cluster |
| endpoint | Management endpoint of the EKS Cluster |
| kubeconfig | Contents of the kubeconfig file used to connect to the cluster for management.  Value should be retrieved with CLI or SDK to ensure proper formatting |
| name | Assigned name of the EKS Cluster |
| setup | Default EKS bootstrapping script for EC2 |

