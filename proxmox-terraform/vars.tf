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
  description = "VM ID of the cloud-init-ready Proxmox template k3snodetpl"
  type        = number
}

variable "proxmox_ssh_username" {
  description = "SSH user used by the provider to upload cloud-init snippets"
  type        = string
  default     = "terraform"
}

variable "snippet_datastore_id" {
  description = "Proxmox datastore with Snippets content enabled"
  type        = string
  default     = "local"
}

variable "k3s_server_url" {
  description = "K3s server URL used by all agent nodes"
  type        = string
  default     = "https://172.16.1.1:6443"
}

variable "k3s_agent_version" {
  description = "K3s version installed on agent nodes"
  type        = string
  default     = "v1.33.4+k3s1"
}

variable "k3s_agent_token" {
  description = "Full K3s agent join token read from the server node-token file"
  type        = string
  sensitive   = true
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
    vmid             = number
    lan_ip           = string
    k3s_ip           = string
    node_external_ip = string

    cpu_cores         = optional(number, 3)
    memory_mb         = optional(number, 4096)
    disk_gb           = optional(number, 10)
    flannel_interface = optional(string, "ens19")
    security_group    = optional(string)
  }))
}
