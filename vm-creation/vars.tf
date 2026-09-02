variable "proxmox_host" {
  description = "Proxmox node name, as returned by the /nodes API"
  default     = "pve"
}

variable "proxmox_api_url" {
  type        = string
  description = "Local Proxmox VE API endpoint"
  default     = "https://192.168.1.106:8006/api2/json"
}

variable "template_name" {
  default = "debiantpl"
}
