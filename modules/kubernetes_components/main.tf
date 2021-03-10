/**
 * # aws-terraform-eks/modules/kubernetes_components
 *
 * This module creates the other required components for EKS to allow additional features like ALB Ingress and Cluster Autoscaler.
 *
 * ## Basic Usage
 *
 * ```
 * module "eks_config" {
 *   source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-eks//modules/kubernetes_components/?ref=v0.0.6"
 *
 *   cluster_name    = "${module.eks_cluster.name}"
 *   kube_map_roles  = "${module.eks_cluster.kube_map_roles}"
 * }
 * ```
 *
 * Full working references are available at [examples](examples)
 */

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data {
    mapRoles = "${var.kube_map_roles}"
  }
}

resource "kubernetes_service_account" "cluster_autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  automount_service_account_token = true
  depends_on                      = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_cluster_role" "cluster_autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  metadata {
    name = "cluster-autoscaler"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  rule {
    verbs      = ["create", "patch"]
    api_groups = [""]
    resources  = ["events", "endpoints"]
  }

  rule {
    verbs      = ["create"]
    api_groups = [""]
    resources  = ["pods/eviction"]
  }

  rule {
    verbs      = ["update"]
    api_groups = [""]
    resources  = ["pods/status"]
  }

  rule {
    verbs          = ["get", "update"]
    api_groups     = [""]
    resources      = ["endpoints"]
    resource_names = ["cluster-autoscaler"]
  }

  rule {
    verbs      = ["watch", "list", "get", "update"]
    api_groups = [""]
    resources  = ["nodes"]
  }

  rule {
    verbs      = ["watch", "list", "get"]
    api_groups = [""]
    resources  = ["pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
  }

  rule {
    verbs      = ["watch", "list", "get"]
    api_groups = ["extensions"]
    resources  = ["replicasets", "daemonsets"]
  }

  rule {
    verbs      = ["watch", "list"]
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
  }

  rule {
    verbs      = ["watch", "list", "get"]
    api_groups = ["apps"]
    resources  = ["statefulsets", "replicasets", "daemonsets"]
  }

  rule {
    verbs      = ["watch", "list", "get"]
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
  }

  rule {
    verbs      = ["get", "list", "watch", "patch"]
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
  }
}

resource "kubernetes_role" "cluster_autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  rule {
    verbs      = ["create", "list", "watch"]
    api_groups = [""]
    resources  = ["configmaps"]
  }

  rule {
    verbs          = ["delete", "get", "update", "watch"]
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_cluster_role_binding" "cluster_autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  metadata {
    name = "cluster-autoscaler"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-autoscaler"
  }
}

resource "kubernetes_role_binding" "cluster_autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"

    labels {
      k8s-addon = "cluster-autoscaler.addons.k8s.io"
      k8s-app   = "cluster-autoscaler"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cluster-autoscaler"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cluster-autoscaler"
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_deployment" "cluster_autoscaler" {
  count = "${var.cluster_autoscaler_enable ? 1 : 0}"

  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"

    labels {
      app = "cluster-autoscaler"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels {
        app = "cluster-autoscaler"
      }
    }

    template {
      metadata {
        labels {
          app = "cluster-autoscaler"
        }
      }

      spec {
        service_account_name             = "cluster-autoscaler"
        termination_grace_period_seconds = "60"
        automount_service_account_token  = "true"

        volume {
          name = "ssl-certs"

          host_path {
            path = "/etc/ssl/certs/ca-bundle.crt"
          }
        }

        container {
          name    = "cluster-autoscaler"
          image   = "gcr.io/google-containers/cluster-autoscaler:v1.15.0"
          command = ["./cluster-autoscaler", "--v=4", "--stderrthreshold=info", "--cloud-provider=aws", "--skip-nodes-with-local-storage=false", "--expander=least-waste", "--node-group-auto-discovery=asg:tag=${var.cluster_autoscaler_tag_key}", "--scale-down-delay-after-add=${var.cluster_autoscaler_scale_down_delay}"]

          resources {
            limits {
              cpu    = "${var.cluster_autoscaler_cpu_limits}"
              memory = "${var.cluster_autoscaler_mem_limits}"
            }

            requests {
              cpu    = "${var.cluster_autoscaler_cpu_requests}"
              memory = "${var.cluster_autoscaler_mem_requests}"
            }
          }

          volume_mount {
            name       = "ssl-certs"
            read_only  = true
            mount_path = "/etc/ssl/certs/ca-certificates.crt"
          }

          image_pull_policy = "Always"
        }
      }
    }
  }

  timeouts = {
    create = "${var.kubernetes_deployment_create_timeout}"
    update = "${var.kubernetes_deployment_update_timeout}"
    delete = "${var.kubernetes_deployment_delete_timeout}"
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_cluster_role" "alb_ingress_controller" {
  count = "${var.alb_ingress_controller_enable ? 1 : 0}"

  metadata {
    name = "alb-ingress-controller"

    labels = [{
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }]
  }

  rule {
    verbs      = ["create", "get", "list", "update", "watch", "patch"]
    api_groups = ["", "extensions"]
    resources  = ["configmaps", "endpoints", "events", "ingresses", "ingresses/status", "services"]
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["", "extensions"]
    resources  = ["nodes", "pods", "secrets", "services", "namespaces"]
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_cluster_role_binding" "alb_ingress_controller" {
  count = "${var.alb_ingress_controller_enable ? 1 : 0}"

  metadata {
    name = "alb-ingress-controller"

    labels = [{
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }]
  }

  subject {
    kind      = "ServiceAccount"
    name      = "alb-ingress-controller"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "alb-ingress-controller"
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_service_account" "alb_ingress_controller" {
  count = "${var.alb_ingress_controller_enable ? 1 : 0}"

  metadata {
    name      = "alb-ingress-controller"
    namespace = "kube-system"

    labels = [{
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }]
  }

  automount_service_account_token = true
  depends_on                      = ["kubernetes_config_map.aws_auth"]
}

resource "kubernetes_deployment" "alb_ingress_controller" {
  count = "${var.alb_ingress_controller_enable ? 1 : 0}"

  metadata {
    name      = "alb-ingress-controller"
    namespace = "kube-system"

    labels = [{
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }]
  }

  spec {
    selector {
      match_labels = [{
        "app.kubernetes.io/name" = "alb-ingress-controller"
      }]
    }

    template {
      metadata {
        labels = [{
          "app.kubernetes.io/name" = "alb-ingress-controller"
        }]
      }

      spec {
        container {
          name  = "alb-ingress-controller"
          image = "docker.io/amazon/aws-alb-ingress-controller:v1.1.2"
          args  = ["--ingress-class=alb", "--cluster-name=${var.cluster_name}", "--aws-max-retries=${var.alb_max_api_retries}", "--v=5"]
        }

        service_account_name            = "alb-ingress-controller"
        automount_service_account_token = "true"
      }
    }
  }

  timeouts = {
    create = "${var.kubernetes_deployment_create_timeout}"
    update = "${var.kubernetes_deployment_update_timeout}"
    delete = "${var.kubernetes_deployment_delete_timeout}"
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}
