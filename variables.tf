variable "name" {
  description = "The desired name for the EKS cluster."
  type        = "string"
}

variable "kubernetes_version" {
  description = "The desired Kubernetes version for your cluster. If you do not specify a value here, the latest version available in Amazon EKS is used."
  type        = "string"
  default     = ""
}

variable "security_groups" {
  description = "List of security groups to apply to the EKS Control Plane.  These groups should enable access to the EKS Worker nodes."
  type        = "list"
}

variable "subnets" {
  description = "List of public and private subnets used for the EKS control plane."
  type        = "list"
}

variable "worker_roles" {
  description = "List of IAM roles assigned to worker nodes."
  type        = "list"
  default     = []
}

variable "worker_roles_count" {
  description = "The number of worker IAM roles provided."
  type        = "string"
  default     = 0
}
