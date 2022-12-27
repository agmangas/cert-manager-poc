terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ctic"

    workspaces {
      name = "gke-cert-manager-poc"
    }
  }
}
