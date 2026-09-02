terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc10"
    }
  }
}

variable "pm_api_token_secret" {
  type        = string
  description = "API Token Secret"
  sensitive   = true
}

provider "proxmox" {
  # Proxmox VE serves its API locally on TCP port 8006.
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = "terraform@pam!new_token_id"
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "test_server" {
  count = 1 # Set to 0 for de-provisioning
  name  = "test-vm-${count.index + 1}"

  target_node = var.proxmox_host
  vmid        = 124 + count.index
  clone       = var.template_name

  # Cloud-init requires qemu-guest-agent to be installed in the template.
  agent   = 1
  os_type = "cloud-init"
  memory  = 2048

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "10G"
          storage = "ssd_disks"
        }
      }
    }
  }

  # If need more duplicate this NIC section
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # We have 3 VMs 121, 122 and 123 before
  ipconfig0 = "ip=192.168.1.${124 + count.index}/24,gw=192.168.1.1"

  # Safer to read during runtime
  sshkeys = <<EOF
    ${file("~/.ssh/id_ed25519.pub")}
    EOF
}
