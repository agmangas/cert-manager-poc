resource "kubernetes_cluster_role_binding" "cluster_admin_binding" {
  metadata {
    name = "cluster-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.cluster_admin_account
  }
}

resource "google_compute_firewall" "ingress_nginx_firewall" {
  name    = "nginx-controller-gke-firewall"
  network = google_compute_network.gke_network.name

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  direction     = "INGRESS"
  source_ranges = [module.gke.master_ipv4_cidr_block]
}

locals {
  mosquitto_namespace = kubernetes_namespace.apps.id
  mosquitto_service   = kubernetes_service.mosquitto.metadata[0].name
  mosquitto_port      = kubernetes_service.mosquitto.spec[0].port[0].port
}

resource "helm_release" "ingress_nginx" {
  depends_on = [
    kubernetes_cluster_role_binding.cluster_admin_binding
  ]

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.4.0"

  # Uncomment the following to ensure that all TCP endpoints are removed:
  # values = [
  #   <<-EOF
  #     tcp:
  #   EOF
  # ]

  set {
    name  = "tcp.1883"
    value = "${local.mosquitto_namespace}/${local.mosquitto_service}:${local.mosquitto_port}"
  }
}
