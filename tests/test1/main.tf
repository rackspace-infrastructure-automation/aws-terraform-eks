provider "aws" {
  version = "~> 1.2"
  region  = "us-west-2"
}

provider "template" {
  version = "~> 1.0"
}

locals {
  eks_cluster_name = "Test-EKS-Cluster"
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//"

  vpc_name = "Test1VPC"

  custom_tags = "${map("kubernetes.io/cluster/${local.eks_cluster_name}", "shared")}"
}

module "sg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//"

  resource_name = "Test-SG"
  vpc_id        = "${module.vpc.vpc_id}"
}

module "eks" {
  source = "../../module"

  name               = "${local.eks_cluster_name}"
  subnets            = "${concat(module.vpc.private_subnets, module.vpc.public_subnets)}" #  Required
  security_groups    = ["${module.sg.eks_control_plane_security_group_id}"]
  worker_roles       = ["${module.ec2_asg.iam_role}"]
  worker_roles_count = "1"

  # kubernetes_version = ""
}

# Lookup the correct AMI based on the region specified
data "aws_ami" "eks" {
  most_recent = true
  owners      = ["602401143452"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }
}

module "ec2_asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg//"

  ec2_os                    = "amazoneks"
  subnets                   = ["${module.vpc.private_subnets}"]
  image_id                  = "${data.aws_ami.eks.image_id}"
  instance_type             = "t2.medium"
  resource_name             = "my_eks_worker_nodes"
  security_group_list       = ["${module.sg.eks_worker_security_group_id}"]
  initial_userdata_commands = "${module.eks.setup}"

  additional_tags = [
    {
      key                 = "kubernetes.io/cluster/${module.eks.name}"
      value               = "owned"
      propagate_at_launch = true
    },
  ]
}

output kubeconfig {
  value = "${module.eks.kubeconfig}"
}

output aws_auth_cm {
  value = "${module.eks.aws_auth_cm}"
}
