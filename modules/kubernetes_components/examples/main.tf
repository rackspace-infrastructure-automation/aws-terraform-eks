terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 2.41"
  region  = "us-west-2"
}

provider "random" {
  version = "~> 2.0"
}

# due to an issue with the K8S provider we are having to pin it to 1.9 at the latest until this issue is resolved.
# https://github.com/terraform-providers/terraform-provider-kubernetes/issues/679

provider "kubernetes" {
  version = "= 1.9"

  cluster_ca_certificate = base64decode(module.eks.certificate_authority_data)
  host                   = module.eks.endpoint
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.eks.token
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.name
}

resource "random_string" "r_string" {
  length  = 6
  special = false
}

locals {
  cluster_name = "Test-EKS-${random_string.r_string.result}"
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork?ref=v0.12.2"

  name = "Test-EKS-VPC-${random_string.r_string.result}"

  custom_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }

  public_subnet_tags = [
    {
      "kubernetes.io/role/elb" = 1
    },
  ]
}

module "sg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group?ref=v0.12.2"

  name   = "Test-SG-${random_string.r_string.result}"
  vpc_id = module.vpc.vpc_id
}

module "eks" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/cluster?ref=v0.12.2"

  enabled_cluster_log_types = []
  name                      = local.cluster_name
  security_groups           = [module.sg.eks_control_plane_security_group_id]
  subnets                   = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  worker_roles              = [module.worker1.iam_role, module.worker2.iam_role]
  worker_roles_count        = "2"
}

data "aws_ami" "eks" {
  most_recent = true
  owners      = ["602401143452"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "worker1" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg?ref=v0.12.3"

  ec2_os                                 = "amazoneks"
  enable_scaling_actions                 = false
  image_id                               = data.aws_ami.eks.image_id
  initial_userdata_commands              = module.eks.setup
  instance_type                          = "t2.medium"
  instance_role_managed_policy_arns      = module.eks.iam_all_node_policies
  instance_role_managed_policy_arn_count = "3"
  name                                   = "Test_eks_worker1_nodes_${random_string.r_string.result}"
  scaling_min                            = "1"
  scaling_max                            = "2"
  security_groups                        = [module.sg.eks_worker_security_group_id]
  subnets                                = [element(module.vpc.private_subnets, 0)]

  tags = {
    "kubernetes.io/cluster/${module.eks.name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"        = ""
  }
}

module "worker2" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg?ref=v0.12.3"

  ec2_os                                 = "amazoneks"
  enable_scaling_actions                 = false
  image_id                               = data.aws_ami.eks.image_id
  initial_userdata_commands              = module.eks.setup
  instance_role_managed_policy_arn_count = "3"
  instance_type                          = "t2.medium"
  name                                   = "Test_eks_worker2_nodes_${random_string.r_string.result}"
  scaling_min                            = "1"
  scaling_max                            = "2"
  security_groups                        = [module.sg.eks_worker_security_group_id]
  subnets                                = [element(module.vpc.private_subnets, 1)]

  instance_role_managed_policy_arns = [
    module.eks.iam_alb_ingress,
    module.eks.iam_autoscaler,
    module.eks.iam_cw_logs,
  ]

  tags = {
    "kubernetes.io/cluster/${module.eks.name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"        = ""
  }
}

module "kubernetes_components" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/kubernetes_components?ref=v0.12.2"

  alb_ingress_controller_enable = true
  cluster_autoscaler_enable     = true
  cluster_name                  = module.eks.name
  kube_map_roles                = module.eks.kube_map_roles
}

