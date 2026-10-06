terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112"
    }
  }
}

variable "pm_api_token_secret" {
  type        = string
  description = "API token secret"
  sensitive   = true
}

# The bpg provider expects the PVE endpoint without /api2/json.
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "terraform@pam!new_token_id=${var.pm_api_token_secret}"
  insecure  = true
}
