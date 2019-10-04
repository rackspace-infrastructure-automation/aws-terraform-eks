output "kubeconfig" {
  description = "output of the kubeconfig"
  value       = "${module.eks.kubeconfig}"
}

output "aws_auth_cm" {
  description = "output of the aws auth"
  value       = "${module.eks.aws_auth_cm}"
}
