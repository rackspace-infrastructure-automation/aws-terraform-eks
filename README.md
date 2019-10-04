# aws-terraform-eks

This repository contains several terraform modules that can be used to deploy various EKS resources, such as an EKS cluster.

## Module listing

- [cluster](.modules/cluster) This module creates an EKS cluster, associated cluster IAM role, and applies EKS worker policies to the worker node IAM roles.
