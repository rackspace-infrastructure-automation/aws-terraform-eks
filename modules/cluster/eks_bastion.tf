locals {
  bastion_ssm_command_list = concat(
    local.bastion_ssm_update_agent
  )

  bastion_ssm_update_agent = [
    {
      action = "aws:runDocument",
      inputs = {
        documentPath = "AWS-UpdateSSMAgent",
        documentType = "SSMDocument"
      },
      name           = "UpdateSSMAgent",
      timeoutSeconds = 300
    },
  ]
}

## Bastion Instance

data "aws_ami" "bastion_amz2_ami" {
  most_recent      = true
  owners           = ["137112412989"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-ebs"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "bastion_user_data" {
  template = file("${path.module}/text/bastion_userdata.sh")
}

data "aws_iam_policy_document" "bastion_assume_role_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_security_group" "bastion_eks_access" {
  count = var.create_bastion ? 1 : 0

  name        = "bastion_eks_access"
  description = "Allow Bastion server to communicate with the cluster API Server"
  vpc_id      = aws_eks_cluster.cluster.vpc_config[0].vpc_id

  ingress {
    description = "EKS control plane communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion_eks_access"
    BastionCluster = var.name
  }
}

data "aws_iam_policy_document" "bastion_instance_role_policies" {

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ssm:CreateAssociation",
      "ssm:DescribeInstanceInformation",
      "ssm:GetParameter",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:PutMetricData",
      "ec2:DescribeTags",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect    = "Allow"
    resources = ["arn:aws:s3:::rackspace-*/*"]

    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetEncryptionConfiguration",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
  }
}

resource "aws_iam_policy" "create_bastion_role_policy" {
  count = var.create_bastion ? 1 : 0

  description = "Rackspace Instance Role Policies for EC2"
  name        = "InstanceRolePolicy-${var.name}"
  policy      = data.aws_iam_policy_document.bastion_instance_role_policies.json
}

resource "aws_iam_role" "bastion_instance_role" {
  count = var.create_bastion ? 1 : 0

  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role_policy_doc.json
  name               = "InstanceRole-${var.name}"
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "attach_core_ssm_policy" {
  count = var.create_bastion ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion_instance_role[0].name
}

resource "aws_iam_role_policy_attachment" "attach_cw_ssm_policy" {
  count = var.create_bastion ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.bastion_instance_role[0].name
}

resource "aws_iam_role_policy_attachment" "attach_instance_role_policy" {
  count = var.create_bastion ? 1 : 0

  policy_arn = aws_iam_policy.create_bastion_role_policy[0].arn
  role       = aws_iam_role.bastion_instance_role[0].name
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  count = var.create_bastion ? 1 : 0

  name = "EKSBastionInstanceProfile-${var.name}"
  path = "/"
  role = aws_iam_role.bastion_instance_role[0].name
}

resource "aws_instance" "bastion_instance" {
  count = var.create_bastion ? 1 : 0

  ami                     = data.aws_ami.bastion_amz2_ami
  instance_type           = "t2.micro"
  subnet_id               = var.bastion_subnet
  tags                    = merge(var.tags, local.tags, { Name = "${var.name}_cluster_bastion" })
  user_data_base64        = base64encode(data.template_file.bastion_user_data.rendered)
  vpc_security_group_ids  = var.bastion_security_groups

  iam_instance_profile = aws_iam_instance_profile.bastion_instance_profile.*.name
}
