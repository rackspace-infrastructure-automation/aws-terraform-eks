provider "aws" {
  version = "~> 2.7"
  region  = "us-west-2"
}

provider "template" {
  version = "~> 1.0"
}

provider "random" {
  version = "~> 1.0"
}

resource "random_string" "r_string" {
  length  = 6
  special = false
  lower   = true
  upper   = false
  number  = false
}

locals {
  eks_cluster_name = "Test-EKS"
}

data "aws_vpc" "selected" {
  default = true
}

data "aws_subnet_ids" "selected" {
  vpc_id = "${data.aws_vpc.selected.id}"
}

module "eks_sg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group?ref=master"

  resource_name = "Test-EKS-SG-${random_string.r_string.result}"
  vpc_id        = "${data.aws_vpc.selected.id}"
}

module "eks" {
  source = "../../module/modules/cluster"

  name                      = "${local.eks_cluster_name}-${random_string.r_string.result}"
  enabled_cluster_log_types = []                                                           #  All are enabled by default. Test to ensure disabling doesn't break
  subnets                   = "${data.aws_subnet_ids.selected.ids}"                        #  Required
  security_groups           = ["${module.eks_sg.eks_control_plane_security_group_id}"]
  worker_roles              = ["${module.ec2_asg.iam_role}"]
  worker_roles_count        = "1"

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

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "ec2_asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg?ref=master"

  ec2_os                    = "amazoneks"
  subnets                   = "${data.aws_subnet_ids.selected.ids}"
  image_id                  = "${data.aws_ami.eks.image_id}"
  instance_type             = "t2.medium"
  resource_name             = "Test_eks_worker_nodes_${random_string.r_string.result}"
  security_group_list       = ["${module.eks_sg.eks_worker_security_group_id}"]
  initial_userdata_commands = "${module.eks.setup}"

  additional_tags = [
    {
      key                 = "kubernetes.io/cluster/${module.eks.name}"
      value               = "owned"
      propagate_at_launch = true
    },
  ]
}
