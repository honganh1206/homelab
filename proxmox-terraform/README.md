# Proxmox K3s Agents

Terraform configuration for K3s agent VMs and their Datacenter firewall aliases/IPSet on Proxmox VE.

## Prerequisites

- Terraform 1.x
- A Proxmox VM template
- Proxmox API token `terraform@pam!new_token_id`
- The API token must have permission to manage VMs and Datacenter firewall objects.
- The `ssd_disks` datastore and bridges `vmbr0` and `vmbr1` must exist.

## Configuration

Create a local `terraform.tfvars` file. Do not commit it.

```hcl
template_vmid        = 9000
pm_api_token_secret  = "<Proxmox API token secret>"

k3s_agents = {
  k3sagent01 = {
    vmid   = 121
    lan_ip = "192.168.1.121"
    k3s_ip = "172.16.2.1"

    # Optional defaults: 3 cores, 4096 MiB RAM, 10 GiB per disk.
    cpu_cores    = 3
    memory_mb    = 4096
    disk_gb      = 10
    data_disk_gb = 10
  }
}
```

Cloud-init network configuration assigns `lan_ip` to net0 and `k3s_ip` to net1, both with a /24 prefix.
Net0 uses gateway `192.168.1.1`. The firewall alias also uses `lan_ip`.
Configure SSH access and k3s manually. Terraform does not supply a k3s installation script.

The default Datacenter IPSet is `k3s-agents`. Terraform creates an alias named `<agent>_net0` for each agent, then adds it to the IPSet as `dc/<agent>_net0`. It also creates the VM-level `ipfilter-net0` IPSet containing that alias, which is required because net0 IP filtering is enabled.

To retain additional IPSet members, declare them:

```hcl
k3s_agent_ipset = {
  name    = "k3s-agents"
  comment = "K3s agent LAN addresses"
  members = {
    management = {
      name    = "192.168.1.10"
      comment = "Management host"
    }
  }
}
```

The IPSet resource is authoritative. Terraform removes IPSet entries that are not declared in `members` or generated from `k3s_agents`.

## Use

```bash
cd proxmox-terraform
terraform init
terraform plan
terraform apply
```

If `k3s-agents` already exists, configure all its retained members, then import it before the first apply:

```bash
terraform import \
  'proxmox_virtual_environment_firewall_ipset.k3s_agent["managed"]' \
  'cluster/k3s-agents'
```

If an agent VM already exists, either remove it before applying or import it using:

```bash
terraform import \
  'proxmox_virtual_environment_vm.k3s_agent["k3sagent01"]' \
  'pve/121'
```

## Manual node configuration

Terraform uses an initialization drive for guest network configuration but does not generate custom cloud-init snippets or install k3s.
Existing guest files and the manually installed k3s service remain outside Terraform management.

Before applying this change to an existing VM, review `terraform plan` for network changes and obsolete snippet deletion.
Do not apply a plan that replaces the manually configured VM.
Removing the configuration does not erase join tokens from historical state files. Keep those files private.

## Disk storage

`scsi0` is the first virtual SCSI disk attached to the VM. This configuration uses it as the boot disk.
`disk_gb` controls its size. `data_disk_gb` controls the second disk, `scsi1`, and defaults to 10 GiB per agent.
Terraform does not format or mount `scsi1`. PostgreSQL and private media can use that disk after guest preparation.

After enlarging a disk, expand the guest partition and filesystem if they do not grow automatically.
If PostgreSQL and media use the boot disk instead, they share available space with the operating system, container images, and logs.
Local PV capacities do not impose filesystem quotas. Monitor free space and keep backups outside this VM.

## Recreate or de-provision an agent

Replacing a VM requires manual SSH access and k3s configuration on the replacement.

Before replacing or removing a joined node, drain it from a K3s server:

```bash
kubectl drain k3sagent03 --ignore-daemonsets --delete-emptydir-data
kubectl delete node k3sagent03
```

To recreate one agent while retaining its Terraform entry and VMID:

```bash
terraform apply -replace='proxmox_virtual_environment_vm.k3s_agent["k3sagent03"]'
```

To de-provision an agent, remove its entry from `k3s_agents` in `terraform.tfvars`, then apply:

```bash
terraform apply
```

Terraform destroys that VM, its firewall options and VM-level IPSet, its Datacenter alias, and its generated IPSet entry. Do not use a targeted destroy for normal de-provisioning because the shared IPSet must also be updated.

## Notes

- The provider is `bpg/proxmox`.
- The Proxmox API endpoint is configured by `proxmox_api_url`; the provider configuration accepts the existing value with `/api2/json` and removes that suffix.
