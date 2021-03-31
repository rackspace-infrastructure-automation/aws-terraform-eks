terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 3.0"
  region  = "us-west-2"
}

provider "kubernetes" {
  version = "~> 2.0"

  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
  host                   = data.aws_eks_cluster.eks.endpoint
  token                  = data.aws_eks_cluster_auth.eks.token
}

provider "random" {
  version = "~> 2.0"
}

provider "template" {
  version = "~> 2.0"
}

data "aws_eks_cluster" "eks" {
  name = module.eks.name
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.name
}

resource "random_string" "r_string" {
  length  = 6
  special = false
  lower   = true
  upper   = false
  number  = false
}

locals {
  tags = {
    Environment     = "Test"
    Purpose         = "Testing aws-terraform-eks"
    ServiceProvider = "Rackspace"
    Terraform       = "true"
  }

  eks_cluster_name = "${local.tags["Environment"]}-EKS"
}

data "aws_vpc" "selected" {
  default = true
}

data "aws_subnet_ids" "selected" {
  vpc_id = data.aws_vpc.selected.id
}

module "eks_sg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group?ref=master"

  name   = "${local.eks_cluster_name}-SG-${random_string.r_string.result}"
  vpc_id = data.aws_vpc.selected.id
}

module "eks" {
  source = "../../module/modules/cluster"

  name                      = "${local.eks_cluster_name}-${random_string.r_string.result}"
  enabled_cluster_log_types = []
  subnets                   = data.aws_subnet_ids.selected.ids
  security_groups           = [module.eks_sg.eks_control_plane_security_group_id]
  tags                      = local.tags
  worker_roles              = [module.ec2_asg.iam_role, module.ec2_asg2.iam_role]
  worker_roles_count        = 2
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

module "ec2_asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg?ref=master"

  ec2_os                                 = "amazoneks"
  image_id                               = data.aws_ami.eks.image_id
  initial_userdata_commands              = module.eks.setup
  instance_role_managed_policy_arn_count = 3
  instance_role_managed_policy_arns      = module.eks.iam_all_node_policies
  instance_type                          = "t2.medium"
  name                                   = "Test_eks_worker_nodes_${random_string.r_string.result}"
  scaling_max                            = 2
  scaling_min                            = 1
  security_groups                        = [module.eks_sg.eks_worker_security_group_id]
  subnets                                = data.aws_subnet_ids.selected.ids

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${module.eks.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"        = ""
    },
  )
}

data "aws_ami" "windows_eks" {
  most_recent = true
  owners      = ["801119661308"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-EKS_Optimized*"]
  }
}

module "ec2_asg2" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg?ref=master"

  ec2_os                                 = "windows2019"
  image_id                               = data.aws_ami.windows_eks.image_id
  initial_userdata_commands              = module.eks.setup_windows
  instance_role_managed_policy_arn_count = 3
  instance_role_managed_policy_arns      = module.eks.iam_all_node_policies
  instance_type                          = "t2.medium"
  name                                   = "Test_eks_win_worker_nodes_${random_string.r_string.result}"
  scaling_max                            = 2
  scaling_min                            = 1
  security_groups                        = [module.eks_sg.eks_worker_security_group_id]
  subnets                                = data.aws_subnet_ids.selected.ids

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${module.eks.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"        = ""
    },
  )
}

module "kubernetes_components" {
  source = "../../module/modules/kubernetes_components"

  alb_ingress_controller_enable = true
  cluster_autoscaler_enable     = true
  cluster_name                  = module.eks.name
  kube_map_roles                = module.eks.kube_map_roles
}
