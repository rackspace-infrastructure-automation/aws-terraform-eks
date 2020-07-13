provider "aws" {
  version = "~> 2.52"
  region  = "us-west-2"
}

provider "template" {
  version = "~> 2.0"
}

locals {
  eks_cluster_name = "Test-EKS-Cluster"
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork?ref=v0.0.10"

  vpc_name = "Test1VPC"

  custom_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }
}

module "sg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group?ref=v0.0.6"

  resource_name = "Test-SG"
  vpc_id        = "${module.vpc.vpc_id}"
}

module "eks" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/cluster?ref=v0.0.6"

  name               = "${local.eks_cluster_name}"
  security_groups    = ["${module.sg.eks_control_plane_security_group_id}"]
  subnets            = "${concat(module.vpc.private_subnets, module.vpc.public_subnets)}" #  Required
  worker_roles       = ["${module.ec2_asg.iam_role}"]
  worker_roles_count = 1

  # kubernetes_version = ""
}

# Lookup the correct AMI based on the region specified
data "aws_ami" "eks" {
  most_recent = true
  owners      = ["602401143452"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.kubernetes_version}*"]
  }
}

module "ec2_asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg?ref=v0.0.25"

  ec2_os                    = "amazoneks"
  image_id                  = "${data.aws_ami.eks.image_id}"
  initial_userdata_commands = "${module.eks.setup}"
  instance_type             = "t2.medium"
  resource_name             = "my_eks_worker_nodes"
  security_group_list       = ["${module.eks.cluster_security_group_id}"]
  subnets                   = ["${module.vpc.private_subnets}"]

  additional_tags = [
    {
      key                 = "kubernetes.io/cluster/${module.eks.name}"
      value               = "owned"
      propagate_at_launch = true
    },
  ]
}
