resource "kubernetes_namespace" "apps" {
  metadata {
    annotations = {
      name = "apps"
    }
    name = "apps"
  }
}

locals {
  issuer_staging        = "letsencrypt-staging"
  issuer_prod           = "letsencrypt-prod"
  issuer_secret_staging = "letsencrypt-staging"
  issuer_secret_prod    = "letsencrypt-prod"
}

# Annotation cluster-autoscaler.kubernetes.io/safe-to-evict is required due to GKE autoscaler issues:
# https://github.com/cert-manager/cert-manager/issues/5267

resource "kubectl_manifest" "letsencrypt_staging_issuer" {
  depends_on = [
    time_sleep.wait_after_helm_cert_manager
  ]

  yaml_body = <<-EOF
    apiVersion: cert-manager.io/v1
    kind: Issuer
    metadata:
      name: ${local.issuer_staging}
      namespace: ${kubernetes_namespace.apps.id}
    spec:
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: ${var.cluster_admin_account}
        privateKeySecretRef:
          name: ${local.issuer_secret_staging}
        solvers:
        - http01:
            ingress:
              class: nginx
              podTemplate:
                metadata:
                  annotations:
                    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
    EOF
}

resource "kubectl_manifest" "letsencrypt_prod_issuer" {
  depends_on = [
    time_sleep.wait_after_helm_cert_manager
  ]

  yaml_body = <<-EOF
    apiVersion: cert-manager.io/v1
    kind: Issuer
    metadata:
      name: ${local.issuer_prod}
      namespace: ${kubernetes_namespace.apps.id}
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.cluster_admin_account}
        privateKeySecretRef:
          name: ${local.issuer_secret_prod}
        solvers:
        - http01:
            ingress:
              class: nginx
              podTemplate:
                metadata:
                  annotations:
                    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
    EOF
}

locals {
  nginx_app = "nginx-app"
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.apps.id
    labels = {
      app = local.nginx_app
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = local.nginx_app
      }
    }
    template {
      metadata {
        labels = {
          app = local.nginx_app
        }
      }
      spec {
        container {
          image = "nginx:1.23"
          name  = "nginx-example"
          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.apps.id
  }
  spec {
    selector = {
      app = local.nginx_app
    }
    port {
      port        = 8080
      target_port = 80
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx-ingress"
    namespace = kubernetes_namespace.apps.id

    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/issuer"      = local.issuer_prod
    }
  }

  spec {
    tls {
      secret_name = "nginx-ingress-tls-secret"
      hosts       = [var.domain_nginx]
    }

    rule {
      host = var.domain_nginx

      http {
        path {
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = 8080
              }
            }
          }

          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}

locals {
  hello_app = "hello-app"
}

resource "kubernetes_deployment" "hello" {
  metadata {
    name      = "hello-deployment"
    namespace = kubernetes_namespace.apps.id
    labels = {
      app = local.hello_app
    }
  }
  spec {
    selector {
      match_labels = {
        app = local.hello_app
      }
    }
    template {
      metadata {
        labels = {
          app = local.hello_app
        }
      }
      spec {
        container {
          image = "us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0"
          name  = "hello-app"
          port {
            container_port = 8080
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "150m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "hello" {
  metadata {
    name      = "hello-service"
    namespace = kubernetes_namespace.apps.id
  }
  spec {
    selector = {
      app = local.hello_app
    }
    port {
      port        = 9090
      target_port = 8080
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "hello" {
  metadata {
    name      = "hello-ingress"
    namespace = kubernetes_namespace.apps.id

    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/issuer"      = local.issuer_prod
    }
  }

  spec {
    tls {
      secret_name = "hello-ingress-tls-secret"
      hosts       = [var.domain_hello]
    }

    rule {
      host = var.domain_hello

      http {
        path {
          backend {
            service {
              name = kubernetes_service.hello.metadata[0].name
              port {
                number = 9090
              }
            }
          }

          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}

# A dummy service that serves as backend for ingress resources that are created 
# only to be used by cert-manager to issue a certificate for L4 services.

locals {
  dummy_backend_app = "dummy-backend-app"
}

resource "kubernetes_deployment" "dummy_backend" {
  metadata {
    name      = "dummy-backend-deployment"
    namespace = kubernetes_namespace.apps.id
    labels = {
      app = local.dummy_backend_app
    }
  }
  spec {
    selector {
      match_labels = {
        app = local.dummy_backend_app
      }
    }
    template {
      metadata {
        labels = {
          app = local.dummy_backend_app
        }
      }
      spec {
        container {
          image = "us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0"
          name  = "dummy-backend"
          port {
            container_port = 8080
          }
          resources {
            limits = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "dummy_backend" {
  metadata {
    name      = "dummy-backend-service"
    namespace = kubernetes_namespace.apps.id
  }
  spec {
    selector = {
      app = local.dummy_backend_app
    }
    port {
      protocol    = "TCP"
      port        = 8080
      target_port = 8080
    }
    type = "NodePort"
  }
}

locals {
  mosquitto_app        = "mosquitto-broker"
  mosquitto_tls_secret = "mosquitto-ingress-tls-secret"
}

resource "kubernetes_config_map" "mosquitto_config_map" {
  metadata {
    name      = "mosquitto-config"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    "mosquitto.conf" = "${file("${path.module}/mosquitto.conf")}"
  }
}

resource "kubernetes_deployment" "mosquitto" {
  metadata {
    name      = "mosquitto-deployment"
    namespace = kubernetes_namespace.apps.id
    labels = {
      app = local.mosquitto_app
    }
  }
  spec {
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "100%"
        max_unavailable = "100%"
      }
    }
    selector {
      match_labels = {
        app = local.mosquitto_app
      }
    }
    template {
      metadata {
        labels = {
          app = local.mosquitto_app
        }
      }
      spec {
        container {
          image = "eclipse-mosquitto:2"
          name  = "mosquitto-broker"
          port {
            container_port = 1883
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
          volume_mount {
            name       = "certificates"
            mount_path = "/etc/certificates"
            read_only  = true
          }
          volume_mount {
            name       = "config"
            mount_path = "/mosquitto/config"
            read_only  = true
          }
        }
        volume {
          name = "certificates"
          secret {
            secret_name = local.mosquitto_tls_secret
            optional    = false
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.mosquitto_config_map.metadata[0].name
            items {
              key  = "mosquitto.conf"
              path = "mosquitto.conf"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mosquitto" {
  metadata {
    name      = "mosquitto-service"
    namespace = kubernetes_namespace.apps.id
  }
  spec {
    selector = {
      app = local.mosquitto_app
    }
    port {
      protocol    = "TCP"
      port        = 1883
      target_port = 1883
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "mosquitto" {
  metadata {
    name      = "mosquitto-dummy-ingress"
    namespace = kubernetes_namespace.apps.id

    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/issuer"      = local.issuer_prod
      "ctic.es/dummy-l4-ingress"    = "true"
    }
  }

  spec {
    tls {
      secret_name = local.mosquitto_tls_secret
      hosts       = [var.domain_mqtt]
    }

    default_backend {
      service {
        name = kubernetes_service.dummy_backend.metadata[0].name
        port {
          number = 8080
        }
      }
    }
  }
}
