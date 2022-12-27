resource "google_compute_network" "gke_network" {
  name = "gke-vpc-network"
}

locals {
  secondary_range_pods     = "secondary-range-pods"
  secondary_range_services = "secondary-range-services"
}

resource "google_compute_subnetwork" "gke_subnetwork" {
  name          = "gke-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "europe-west1"
  network       = google_compute_network.gke_network.id

  secondary_ip_range {
    range_name    = local.secondary_range_pods
    ip_cidr_range = "10.10.0.0/16"
  }

  secondary_ip_range {
    range_name    = local.secondary_range_services
    ip_cidr_range = "10.11.0.0/16"
  }
}

resource "google_compute_router" "router" {
  name    = "private-gke-router"
  region  = google_compute_subnetwork.gke_subnetwork.region
  network = google_compute_network.gke_network.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "private-gke-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
