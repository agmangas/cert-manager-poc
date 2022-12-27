variable "project_id" {
  type        = string
  description = "Google Cloud project ID"
}

variable "network_tier" {
  type    = string
  default = "STANDARD"
}

variable "cluster_admin_account" {
  type        = string
  description = "Google Cloud account as reported by 'gcloud config get-value account'"
}

variable "domain_nginx" {
  type        = string
  description = "Domain name for the NGINX service"
}

variable "domain_hello" {
  type        = string
  description = "Domain name for the Hello App service"
}

variable "domain_mqtt" {
  type        = string
  description = "Domain name for the MQTT broker service"
}
