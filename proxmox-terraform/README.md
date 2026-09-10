# Proxmox K3s Agents

Terraform configuration for K3s agent VMs and their Datacenter firewall aliases/IPSet on Proxmox VE.

## Prerequisites

- Terraform 1.x
- A cloud-init-ready Proxmox VM template
- Proxmox API token `terraform@pam!new_token_id`
- The API token must have permission to manage VMs and Datacenter firewall objects.
- The `ssd_disks` datastore and bridges `vmbr0` and `vmbr1` must exist.
- The `local` datastore must have the `Snippets` content type enabled, or set `snippet_datastore_id` to a datastore that does.
- SSH-agent access to the Proxmox node is required to upload cloud-init snippets. The default SSH user is `root`; set `proxmox_ssh_username` if needed.

## Configuration

Create a local `terraform.tfvars` file. Do not commit it.

```hcl
template_vmid        = 9000
pm_api_token_secret  = "<Proxmox API token secret>"
k3s_agent_token      = "K10<cluster-ca-hash>::node:<credentials>"
k3s_agent_version    = "v1.33.4+k3s1"
# snippet_datastore_id = "local"
# proxmox_ssh_username = "root"

k3s_agents = {
  k3sagent01 = {
    vmid             = 121
    lan_ip           = "192.168.1.121"
    k3s_ip           = "172.16.2.1"
    node_external_ip = "10.4.2.1"

    # Optional defaults: 3 cores, 4096 MiB RAM, 10 GiB disk, ens19.
    cpu_cores = 3
    memory_mb = 4096
    disk_gb   = 10
  }
}
```

`lan_ip` is configured on `vmbr0` (net0). `k3s_ip` is configured on `vmbr1` (net1). Ensure `node_external_ip` is assigned to, and reachable from, the node before using it in K3s configuration.

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

## K3s cloud-init

For each agent, Terraform uploads a cloud-init snippet before creating the VM. On first boot it writes:

- `/etc/rancher/config.yaml.d/config.yaml`
- `/etc/rancher/config.yaml.d/kubelet.conf`
- symlinks at `/etc/rancher/k3s/config.yaml` and `/etc/rancher/k3s/kubelet.conf`

The generated K3s configuration uses each agent's `k3s_ip`, `node_external_ip`, and `flannel_interface`, plus the shared `k3s_server_url` and `k3s_agent_token`. It then installs the agent with:

```bash
wget -qO - https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.4+k3s1" sh -s - agent
```

Set `k3s_agent_version` to change the installed version.

Read the full join token from the K3s server:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Prefer injecting it at runtime instead of placing it in a tfvars file:

```bash
export TF_VAR_k3s_agent_token='K10...::node:...'
terraform apply
```

The cloud-init snippet contains the token and Terraform state therefore contains it. Keep state private and encrypted where possible.

## Recreate or de-provision an agent

Cloud-init runs during first boot. To apply changed K3s cloud-init settings, recreate the VM.

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

Terraform destroys that VM, its firewall options and VM-level IPSet, its Datacenter alias, its cloud-init snippet, and its generated IPSet entry. Do not use a targeted destroy for normal de-provisioning because the shared IPSet must also be updated.

## Notes

- The provider is `bpg/proxmox`.
- The Proxmox API endpoint is configured by `proxmox_api_url`; the provider configuration accepts the existing value with `/api2/json` and removes that suffix.
