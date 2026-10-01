resource "proxmox_virtual_environment_file" "k3s_agent_cloud_init" {
  for_each = var.k3s_agents

  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = var.proxmox_host

  # TODO: cloud-init caused OOM on VM 124 (4 GiB)
  source_raw {
    data = <<-CLOUD_INIT
      #cloud-config
      ${yamlencode({
    ssh_authorized_keys = [trimspace(file("~/.ssh/id_ed25519.pub"))]
    bootcmd = [
      ["mkdir", "-p", "/etc/rancher/config.yaml.d", "/etc/rancher/k3s"],
      ["touch", "/etc/rancher/config.yaml.d/config.yaml", "/etc/rancher/config.yaml.d/kubelet.conf"],
    ]
    write_files = [
      {
        path        = "/etc/rancher/config.yaml.d/kubelet.conf"
        permissions = "0600"
        content     = <<-KUBELET_CONFIG
              # Kubelet configuration
              apiVersion: kubelet.config.k8s.io/v1beta1
              kind: KubeletConfiguration

              shutdownGracePeriod: 30s
              shutdownGracePeriodCriticalPods: 10s
            KUBELET_CONFIG
      },
      {
        path        = "/etc/rancher/config.yaml.d/config.yaml"
        permissions = "0600"
        content     = <<-K3S_CONFIG
              # ${each.key}

              flannel-iface: "${each.value.flannel_interface}"
              node-ip: "${each.value.k3s_ip}"
              node-external-ip: "${each.value.node_external_ip}"
              server: "${var.k3s_server_url}"
              token: "${var.k3s_agent_token}"
              kubelet-arg: "config=/etc/rancher/k3s/kubelet.conf"
              protect-kernel-defaults: true
            K3S_CONFIG
      },
    ]
    runcmd = [
      ["ln", "-sfn", "/etc/rancher/config.yaml.d/config.yaml", "/etc/rancher/k3s/config.yaml"],
      ["ln", "-sfn", "/etc/rancher/config.yaml.d/kubelet.conf", "/etc/rancher/k3s/kubelet.conf"],
      "wget -qO - https://get.k3s.io | INSTALL_K3S_VERSION=\"${var.k3s_agent_version}\" sh -s - agent",
    ]
})}
    CLOUD_INIT

file_name = "${each.key}-k3s-cloud-init.yaml"
}
}

resource "proxmox_virtual_environment_vm" "k3s_agent" {
  for_each = var.k3s_agents

  name      = each.key
  node_name = var.proxmox_host
  vm_id     = each.value.vmid

  clone {
    vm_id = var.template_vmid
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores   = each.value.cpu_cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["scsi0"]

  disk {
    interface    = "scsi0"
    size         = each.value.disk_gb
    datastore_id = "ssd_disks"
  }

  initialization {
    datastore_id = "ssd_disks"

    ip_config {
      ipv4 {
        address = "${each.value.lan_ip}/24"
        gateway = "192.168.1.1"
      }
    }

    ip_config {
      ipv4 {
        address = "${each.value.k3s_ip}/24"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.k3s_agent_cloud_init[each.key].id
  }

  # LAN interface.
  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }

  # Dedicated K3s node-to-node interface. It is isolated by vmbr1 and is not
  # filtered by the Proxmox firewall.
  network_device {
    bridge   = "vmbr1"
    model    = "virtio"
    firewall = false
  }
}

resource "proxmox_virtual_environment_firewall_options" "k3s_agent" {
  for_each = var.k3s_agents

  node_name = var.proxmox_host
  vm_id     = proxmox_virtual_environment_vm.k3s_agent[each.key].vm_id

  enabled       = true
  ndp           = false
  ipfilter      = true
  log_level_in  = "info"
  log_level_out = "info"
}

# Insert the configured existing cluster security group into the node's net0
# firewall rules. This resource is authoritative for that VM's firewall rules.
resource "proxmox_virtual_environment_firewall_rules" "k3s_agent_security_group" {
  for_each = {
    for name, agent in var.k3s_agents : name => agent
    if agent.security_group != null
  }

  node_name = var.proxmox_host
  vm_id     = proxmox_virtual_environment_vm.k3s_agent[each.key].vm_id

  rule {
    security_group = each.value.security_group
    comment        = "K3s agent security group"
    iface          = "net0"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.k3s_agent]
}

# IP filtering is enabled for net0. Allow only the node's assigned LAN address
# to originate traffic on that interface, as required by Proxmox ipfilter.
resource "proxmox_virtual_environment_firewall_ipset" "k3s_agent_net0_ipfilter" {
  for_each = var.k3s_agents

  node_name = var.proxmox_host
  vm_id     = proxmox_virtual_environment_vm.k3s_agent[each.key].vm_id

  name    = "ipfilter-net0"
  comment = "Allowed source address for net0"

  cidr {
    name    = "dc/${proxmox_virtual_environment_firewall_alias.k3s_agent[each.key].name}"
    comment = "${each.key} net0"
  }

  depends_on = [proxmox_virtual_environment_firewall_alias.k3s_agent]
}

# Cluster-level aliases can be referenced directly in rules or as dc/<name>
# entries in a cluster-level IPSet. net0 is the LAN interface.
resource "proxmox_virtual_environment_firewall_alias" "k3s_agent" {
  for_each = var.k3s_agents

  name    = "${each.key}_net0"
  cidr    = each.value.lan_ip
  comment = "K3s agent LAN address"
}

# An IPSet resource is authoritative: declare every member already in the
# existing IPSet before importing it, or Terraform will remove undeclared ones.
resource "proxmox_virtual_environment_firewall_ipset" "k3s_agent" {
  for_each = { managed = var.k3s_agent_ipset }

  name    = each.value.name
  comment = each.value.comment

  dynamic "cidr" {
    for_each = each.value.members
    content {
      name    = cidr.value.name
      comment = cidr.value.comment
      nomatch = cidr.value.nomatch
    }
  }

  dynamic "cidr" {
    for_each = proxmox_virtual_environment_firewall_alias.k3s_agent
    content {
      name    = "dc/${cidr.value.name}"
      comment = "K3s agent ${cidr.value.name}"
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_alias.k3s_agent]
}
