module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version                    = "23.3.0"
  project_id                 = var.project_id
  name                       = "gke-test-terraform"
  region                     = "europe-west1"
  zones                      = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
  network                    = google_compute_network.gke_network.name
  subnetwork                 = google_compute_subnetwork.gke_subnetwork.name
  ip_range_pods              = local.secondary_range_pods
  ip_range_services          = local.secondary_range_services
  http_load_balancing        = true
  network_policy             = true
  horizontal_pod_autoscaling = true
  enable_private_endpoint    = false
  enable_private_nodes       = true
  remove_default_node_pool   = true

  node_pools = [
    {
      name            = "e2-node-pool"
      machine_type    = "e2-standard-2"
      node_locations  = "europe-west1-b,europe-west1-c"
      min_count       = 1
      max_count       = 2
      local_ssd_count = 0
      spot            = false
      disk_size_gb    = 80
      disk_type       = "pd-standard"
      enable_gcfs     = false
      enable_gvnic    = false
      auto_repair     = true
      auto_upgrade    = true
      preemptible     = false
    }
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  node_pools_labels = {
    all = {}

    e2-node-pool = {
      default-node-pool = true
    }
  }

  node_pools_metadata = {
    all = {}
  }

  node_pools_taints = {
    all = []

    e2-node-pool = [
      {
        key    = "default-node-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      }
    ]
  }

  node_pools_tags = {
    all = []

    e2-node-pool = [
      "default-node-pool"
    ]
  }
}

output "master_ipv4_cidr_block" {
  description = "GKE master IPv4 CIDR block"
  value       = module.gke.master_ipv4_cidr_block
}
