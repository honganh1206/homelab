variable "proxmox_host" {
  description = "Proxmox node name, as returned by the /nodes API"
  default     = "pve"
}

variable "proxmox_api_url" {
  type        = string
  description = "Local Proxmox VE API endpoint"
  default     = "https://192.168.1.106:8006"
}

variable "template_vmid" {
  description = "VM ID of the Proxmox template k3snodetpl"
  type        = number
}

# To manage an existing Datacenter IPSet, set its name and declare every
# pre-existing member here before importing it. The K3s-agent aliases are added
# to this IPSet automatically as dc/<agent name>.
variable "k3s_agent_ipset" {
  type = object({
    name    = string
    comment = optional(string)
    members = optional(map(object({
      name    = string
      comment = optional(string)
      nomatch = optional(bool, false)
    })), {})
  })
}

# Add one entry for each new node. The map key is the VM hostname.
variable "k3s_agents" {
  type = map(object({
    vmid   = number
    lan_ip = string
    k3s_ip = string

    cpu_cores      = optional(number, 3)
    memory_mb      = optional(number, 4096)
    disk_gb        = optional(number, 10)
    data_disk_gb   = optional(number, 10)
    ssd_enabled = optional(bool, true)
    security_group = optional(string)
  }))
}
