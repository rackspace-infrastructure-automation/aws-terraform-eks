variable "alb_ingress_controller_enable" {
  description = "A variable to control whether or not the ALB Ingress resources are enabled"
  type        = bool
  default     = true
}

variable "alb_max_api_retries" {
  description = "Maximum number of times to retry the aws calls"
  type        = number
  default     = 10
}

variable "cluster_autoscaler_cpu_limits" {
  description = "CPU Limits for the CA Pod"
  type        = string
  default     = "100m"
}

variable "cluster_autoscaler_cpu_requests" {
  description = "CPU Requests for the CA Pod"
  type        = string
  default     = "100m"
}

variable "cluster_autoscaler_enable" {
  description = "A variable to control whether CA is enabled"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_image" {
  description = "Cluster Autoscaler Image"
  type        = string
  default     = "gcr.io/google-containers/cluster-autoscaler:v1.15.0"
}

variable "cluster_autoscaler_mem_limits" {
  description = "Mem Limits for the CA Pod"
  type        = string
  default     = "300Mi"
}

variable "cluster_autoscaler_mem_requests" {
  description = "Mem requests for the CA Pod"
  type        = string
  default     = "300Mi"
}

variable "cluster_autoscaler_scale_down_delay" {
  description = "CA Scale down delay"
  type        = string
  default     = "5m"
}

variable "cluster_autoscaler_tag_key" {
  description = "Tag key used with CA. Change this only if you have multiple EKS clusters in the same account."
  type        = string
  default     = "k8s.io/cluster-autoscaler/enabled"
}

variable "cluster_name" {
  description = "The name of the EKS Cluster"
  type        = string
}

variable "kube_map_roles" {
  description = "The string used to configure the EKS cluster, retrieved from the EKS Cluster module"
  type        = string
}

variable "kubernetes_deployment_create_timeout" {
  description = "Timeout for creating instances, replicas, and restoring from Snapshots"
  type        = string
  default     = "30m"
}

variable "kubernetes_deployment_delete_timeout" {
  description = "Timeout for destroying databases. This includes the time required to take snapshots"
  type        = string
  default     = "30m"
}

variable "kubernetes_deployment_update_timeout" {
  description = "Timeout for database modifications"
  type        = string
  default     = "30m"
}

