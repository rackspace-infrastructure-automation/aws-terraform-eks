# aws-terraform-eks

This repository contains several terraform modules that can be used to deploy various EKS resources, such as an EKS cluster.

## Module listing

- [cluster](./modules/cluster) This module creates an EKS cluster, associated cluster IAM role, and applies EKS worker policies to the worker node IAM roles.
- [kubernetes_components](./modules/kubernetes_components) This module manages EKS via the kubernetes plugin, enabling additional features like ALB Ingress and Cluster Autoscaler.
