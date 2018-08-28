output "aws_auth_cm" {
  description = "Contents of the aws-auth-cm.yaml used for cluster configuration.  Value should be retrieved with CLI or SDK to ensure proper formatting"
  value       = "${zipmap(var.worker_roles, data.template_file.aws_auth_cm.*.rendered)}"
}

output "certificate_authority_data" {
  description = "Assigned CA data for the EKS Cluster"
  value       = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
}

output "endpoint" {
  description = "Management endpoint of the EKS Cluster"
  value       = "${aws_eks_cluster.cluster.endpoint}"
}

output "kubeconfig" {
  description = "Contents of the kubeconfig file used to connect to the cluster for management.  Value should be retrieved with CLI or SDK to ensure proper formatting"
  value       = "${data.template_file.kubeconfig.rendered}"
}

output "name" {
  description = "Assigned name of the EKS Cluster"
  value       = "${aws_eks_cluster.cluster.id}"
}
