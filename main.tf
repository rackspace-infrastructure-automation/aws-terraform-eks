/**
 * # aws-terraform-eks
 *
 * This module creates an EKS cluster, associated cluster IAM role, and applies EKS worker policies to the worker node IAM roles.
 *
 * In order to get a working cluster: manual steps must be performed **after** the cluster is built.  The module will output the required configuration files to enable client and worker node setup and configuration.
 *
 * **NOTE:** The minimum required version of the Terraform AWS Provider for this module is `2.6.0`.
 *
 *## Basic Usage
 *
 *```
 *module "eks_cluster" {
 *  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//?ref=v0.0.1"
 *
 *  name = "${local.eks_cluster_name}"
 *  subnets = "${concat(module.vpc.private_subnets, module.vpc.public_subnets)}" #  Required
 *  security_groups = ["${module.sg.eks_control_plane_security_group_id}"]
 *
 *  worker_roles       = ["${module.eks_workers.iam_role}"]
 *  worker_roles_count = "1"
 *}
 *```
 *
 * Full working references are available at [examples](examples)
 */

locals {
  cluster_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
  ]

  worker_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

data "aws_iam_policy_document" "assume_service" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name_prefix        = "${var.name}-ControlPlane-"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.assume_service.json}"
}

resource "aws_iam_role_policy_attachment" "attach_control_plane_policy" {
  count = "${length(local.cluster_policies)}"

  role       = "${aws_iam_role.role.name}"
  policy_arn = "${element(local.cluster_policies, count.index)}"
}

resource "aws_iam_role_policy_attachment" "attach_worker_policy" {
  count = "${length(local.worker_policies) * var.worker_roles_count}"

  role       = "${element(var.worker_roles, count.index / length(local.worker_policies))}"
  policy_arn = "${element(local.worker_policies, count.index)}"
}

resource "aws_eks_cluster" "cluster" {
  name                      = "${var.name}"
  enabled_cluster_log_types = "${var.enabled_cluster_log_types}"
  role_arn                  = "${aws_iam_role.role.arn}"
  version                   = "${var.kubernetes_version}"

  vpc_config {
    subnet_ids         = ["${var.subnets}"]
    security_group_ids = ["${var.security_groups}"]
  }
}

data "template_file" "kubeconfig" {
  template = "${file("${path.module}/text/kubeconfig.yaml")}"

  vars = {
    cluster_name = "${aws_eks_cluster.cluster.id}"
    endpoint     = "${aws_eks_cluster.cluster.endpoint}"
    cadata       = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
  }
}

data "aws_iam_role" "worker_roles" {
  count = "${var.worker_roles_count}"

  name = "${element(var.worker_roles, count.index)}"
}

data "template_file" "aws_auth_cm" {
  count    = "${var.worker_roles_count}"
  template = "${file("${path.module}/text/aws-auth-cm.yaml")}"

  vars = {
    iam_role = "${element(data.aws_iam_role.worker_roles.*.arn, count.index)}"
  }
}
