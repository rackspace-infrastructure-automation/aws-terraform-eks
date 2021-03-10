/**
 * # aws-terraform-eks/modules/cluster
 *
 * This module creates an EKS cluster, associated cluster IAM role, and applies EKS worker policies to the worker node IAM roles.
 *
 * In order to get a working cluster: manual steps must be performed **after** the cluster is built.  The module will output the required configuration files to enable client and worker node setup and configuration.
 *
 * **NOTE:** The minimum required version of the Terraform AWS Provider for this module is `2.6.0`.
 *
 * ## Basic Usage
 *
 * ```
 * module "eks_cluster" {
 *   source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/cluster/?ref=v0.0.6"
 *
 *   name               = "${local.eks_cluster_name}"
 *   subnets            = "${concat(module.vpc.private_subnets, module.vpc.public_subnets)}" #  Required
 *   tags               = "${local.tags}"
 *   worker_roles       = ["${module.eks_workers.iam_role}"]
 *   worker_roles_count = 1
 * }
 * ```
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

  tags = {
    Environment     = "${var.environment}"
    ServiceProvider = "Rackspace"
  }

  merged_tags = "${merge(
    local.tags,
    var.tags,
  )}"
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

#
# Required so EKS can create ELBs. This is well described here:
# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/87
#  https://medium.com/faun/aws-eks-the-role-is-not-authorized-to-perform-ec2-describeaccountattributes-error-1c6474781b84
#
resource "aws_iam_service_linked_role" "elasticloadbalancing" {
  count            = "${var.create_elb_service_linked_role ? 1 : 0}"
  aws_service_name = "elasticloadbalancing.amazonaws.com"
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

resource "aws_cloudwatch_log_group" "eks" {
  count = "${var.manage_log_group ? 1 : 0}"

  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = "${var.log_group_retention}"

  tags = "${local.merged_tags}"
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

  tags = "${local.merged_tags}"

  depends_on = [
    "aws_cloudwatch_log_group.eks",
  ]
}

locals {
  kubeconfig_template  = "${path.module}/text/kubeconfig.yaml"
  aws_auth_cm_template = "${path.module}/text/aws-auth-cm.yaml"
  map_roles_template   = "${path.module}/text/map_roles.txt"
}

data "template_file" "kubeconfig" {
  template = "${file(local.kubeconfig_template)}"

  vars = {
    cluster_name = "${aws_eks_cluster.cluster.id}"
    endpoint     = "${aws_eks_cluster.cluster.endpoint}"
    cadata       = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
  }

  depends_on = ["null_resource.cluster_launch"]
}

data "aws_iam_role" "worker_roles" {
  count = "${var.worker_roles_count}"

  name = "${element(var.worker_roles, count.index)}"
}

data "template_file" "aws_auth_cm" {
  count = "${var.worker_roles_count}"

  template = "${file(local.aws_auth_cm_template)}"

  vars = {
    iam_role = "${element(data.aws_iam_role.worker_roles.*.arn, count.index)}"
  }
}

data "template_file" "map_roles" {
  count = "${var.worker_roles_count}"

  template = "${file(local.map_roles_template)}"

  vars = {
    iam_role = "${element(data.aws_iam_role.worker_roles.*.arn, count.index)}"
  }
}

resource "null_resource" "cluster_launch" {
  count = "${var.wait_for_cluster ? 1 : 0}"

  # Sleep for 60 seconds to (hopefully) ensure the cluster is ready before attempting to create
  # the ConfigMap, etc.
  #
  # An unfortunate, seemingly necessary hack to avoid the following timeout error due to slowpoke DNS:
  #   Post <cluster_endpoint>/api/v1/<..etc..>: dial tcp w.x.y.z:443: i/o timeout
  #
  # Once https://github.com/terraform-providers/terraform-provider-aws/pull/11426 has been resolved,
  # we should be able to remove this sleep command.

  provisioner "local-exec" {
    command = "sleep 60"
  }
  triggers = {
    cluster_endpoint = "${aws_eks_cluster.cluster.endpoint}"
  }
}

data "aws_iam_policy_document" "autoscaler" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
  }
}

resource "aws_iam_policy" "autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  description = "Permissions for the EKS autoscaler"
  name_prefix = "${var.name}-Cluster-Autoscaler"
  path        = "/"
  policy      = "${data.aws_iam_policy_document.autoscaler.json}"
}

data "aws_iam_policy_document" "cw_logs" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeTags",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
    ]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    effect    = "Allow"
    resources = ["arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"]
  }
}

resource "aws_iam_policy" "cw_logs" {
  description = "Permissions for Cloudwatch logs"
  name_prefix = "${var.name}-Cloudwatch-Logs"
  path        = "/"
  policy      = "${data.aws_iam_policy_document.cw_logs.json}"
}

data "aws_iam_policy_document" "alb_ingress" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebACL",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates",
    ]
  }

  statement {
    actions   = ["cognito-idp:DescribeUserPoolClient"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "waf-regional:GetWebACLForResource",
      "waf-regional:GetWebACL",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "tag:GetResources",
      "tag:TagResources",
    ]
  }

  statement {
    actions   = ["waf:GetWebACL"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_ingress" {
  count = "${var.alb_ingress_controller_enable ? 1 : 0}"

  description = "Permissions for ALB Ingress Controller"
  name_prefix = "${var.name}-Alb-Ingress"
  path        = "/"
  policy      = "${data.aws_iam_policy_document.alb_ingress.json}"
}
