output "aws_auth_cm" {
  description = "Contents of the aws-auth-cm.yaml used for cluster configuration.  Value should be retrieved with CLI or SDK to ensure proper formatting"
  value       = "${zipmap(var.worker_roles, data.template_file.aws_auth_cm.*.rendered)}"
}

output "certificate_authority_data" {
  description = "Assigned CA data for the EKS Cluster"
  value       = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
  depends_on  = ["null_resource.cluster_launch"]
}

output "endpoint" {
  description = "Management endpoint of the EKS Cluster"
  value       = "${aws_eks_cluster.cluster.endpoint}"
  depends_on  = ["null_resource.cluster_launch"]
}

output "iam_alb_ingress" {
  description = "ARN of the EKS Cluster Node ALB Ingress Controller IAM policy"
  value       = "${join(",", aws_iam_policy.alb_ingress.*.arn)}"
}

output "iam_all_node_policies" {
  description = "ARN of all EKS Cluster Node IAM polices"

  value = "${concat(
    aws_iam_policy.alb_ingress.*.arn,
    aws_iam_policy.autoscaler.*.arn,
    list(aws_iam_policy.cw_logs.arn),
  )}"
}

output "iam_autoscaler" {
  description = "ARN of the EKS Cluster Node Cluster Autoscaler IAM policy"
  value       = "${join(",", aws_iam_policy.autoscaler.*.arn)}"
}

output "iam_cw_logs" {
  description = "ARN of the EKS Cluster Node Cloudwatch Logs IAM policy"
  value       = "${aws_iam_policy.cw_logs.arn}"
}

output "identity" {
  description = "Nested attribute containing identity provider information for your cluster. Only available on Kubernetes version 1.13 and 1.14 clusters created or upgraded on or after September 3, 2019. https://www.terraform.io/docs/providers/aws/r/eks_cluster.html#identity"
  value       = "${aws_eks_cluster.cluster.identity}"
}

output "kubeconfig" {
  description = "Contents of the kubeconfig file used to connect to the cluster for management.  Value should be retrieved with CLI or SDK to ensure proper formatting"
  value       = "${data.template_file.kubeconfig.rendered}"
}

output "kube_map_roles" {
  description = "The string value used to configure the cluster with the kubernetes_config_map resource"
  value       = "${join("", data.template_file.map_roles.*.rendered)}"
}

output "name" {
  description = "Assigned name of the EKS Cluster"
  value       = "${aws_eks_cluster.cluster.id}"
}

output "setup" {
  description = "Default EKS bootstrapping script for EC2"
  value       = "/etc/eks/bootstrap.sh ${var.name} ${var.bootstrap_arguments}\n"
}
