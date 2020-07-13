variable "alb_ingress_controller_enable" {
  description = "A boolean value that determines if IAM policies related to ALB ingress controller should be created."
  type        = "string"
  default     = true
}

variable "bootstrap_arguments" {
  description = "Any optional parameters for the EKS Bootstrapping script. This is ignored for all os's except amazon EKS"
  type        = "string"
  default     = ""
}

variable "bootstrap_arguments_windows" {
  description = "Any optional parameters for the EKS Bootstrapping script. This is ignored for all os's except Windows EKS"
  type        = "string"
  default     = ""
}

variable "cluster_autoscaler_enable" {
  description = "A boolean value that determines if IAM policies related to cluster autoscaler should be created."
  type        = "string"
  default     = true
}

variable "enabled_cluster_log_types" {
  description = "A list of the desired control plane logging to enable. All logs are enabled by default."
  type        = "list"

  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
}

variable "environment" {
  description = "Application environment for which this network is being created. Preferred value are Development, Integration, PreProduction, Production, QA, Staging, or Test"
  type        = "string"
  default     = "Development"
}

variable "kubernetes_version" {
  description = "The desired Kubernetes version for your cluster. If you do not specify a value here, the latest version available in Amazon EKS is used."
  type        = "string"
  default     = ""
}

variable "log_group_retention" {
  description = "Specifies the number of days you want to retain log events in the specified log group. Possible values are: 0 (Never Expire), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653."
  type        = "string"
  default     = 0
}

variable "manage_log_group" {
  description = "Optionally manage the cluster log group via Terraform. Couple with `log_group_retention` to use a retention other than 'Never Expire'."
  type        = "string"
  default     = false
}

variable "name" {
  description = "The desired name for the EKS cluster."
  type        = "string"
}

variable "security_groups" {
  description = "Optional list of additional security groups to apply to the EKS Control Plane.  These groups should enable access to the EKS Worker nodes."
  type        = "list"
  default     = []
}

variable "subnets" {
  description = "List of public and private subnets used for the EKS control plane."
  type        = "list"
}

variable "tags" {
  description = "Additional tags to be added to the Elasticsearch cluster."
  type        = "map"
  default     = {}
}

variable "wait_for_cluster" {
  description = "A variable to control whether we pause deployment after creating the EKS cluster to allow time to fully launch."
  type        = "string"
  default     = true
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
