# Agent guidance

## Repository context

This repository manages a personal homelab with K3s on Proxmox VMs.
Kubernetes configuration uses plain YAML and Kustomize, not Helm templates.
Terraform manages K3s agent VMs and Proxmox firewall resources through `bpg/proxmox`.
Guest SSH access, K3s installation, and data-disk preparation remain manual tasks.

Read `README.md` for architecture notes.
For Terraform changes, also read `proxmox-terraform/README.md`.
Treat the current configuration as the source of truth when documentation differs.
Repository files describe intended configuration, not verified live infrastructure.

## Repository map

| Directory | Purpose |
| --- | --- |
| `proxmox-terraform/` | Agent VMs, network interfaces, firewall rules, aliases, and IP sets |
| `cert-manager/deployment/` | cert-manager installation from an upstream manifest |
| `cert-manager/certificates/` | Self-signed bootstrap issuer, root CA, intermediate CA, and cluster issuers |
| `metallb/` | MetalLB installation, address pool, and L2 advertisement |
| `metrics-server/` | Upstream metrics-server manifest and a local deployment patch |
| `traefik-dashboard/` | Dashboard ingress and basic authentication |
| `headlamp/` | Kubernetes dashboard, access control, ingress, and certificate |
| `forgejo/` | Forgejo, PostgreSQL, Valkey, ingress, certificates, and persistent storage |
| `ghost/` | Ghost, MariaDB, Valkey, ingress, certificates, and persistent storage |
| `monitoring/` | Prometheus, Grafana, kube-state-metrics, and node exporter |

Traefik is the ingress controller bundled with K3s.
MetalLB uses L2 mode for external service addresses.
Service manifests use Traefik `IngressRoute` resources and cert-manager certificates.

## Editing conventions

- Keep changes within the requested service or infrastructure module.
- Preserve unrelated work in the working tree.
- Match the YAML structure and indentation in the surrounding file.
- Keep resource manifests in `resources/` and non-secret configuration in `configs/`.
- Register new manifests in the owning `kustomization.yaml`.
- Reuse the existing `components/<role>-<service>/` layout for application components.
- Preserve the `platform` and `app` label conventions and their selector relationships.
- Inspect Kustomize image overrides before changing container versions.
- Preserve upstream manifest references unless the task requires an upgrade or source change.
- Update the relevant README when commands, prerequisites, or operational behavior change.

The `components/` directories contain ordinary Kustomizations, not necessarily Kustomize `Component` resources.
There is no root `kustomization.yaml` or repository-wide test suite.

## Secrets and local files

Kustomize secret generators reference local files under `secrets/`.
The repository ignores these directories, so a fresh checkout can lack required build inputs.
The Terraform directory also uses local credentials, variable files, and state.

- Never commit credentials, private keys, kubeconfig files, Terraform state, plans, or secret variable files.
- Never print secret values or include rendered Secrets in reports.
- Before adding local credential files, verify that Git ignores their paths.
- If a build lacks secret inputs, report the missing paths without inventing production credentials.
- Do not weaken authentication, TLS, RBAC, or container security to make validation pass.

## Validation

Run checks for the changed configuration only.
Report the commands, results, and limitations.
Do not claim that a local render proves a successful deployment.

For Kubernetes changes, render the owning entrypoint from the repository root:

```sh
# Example: replace forgejo with the affected entrypoint.
kubectl kustomize forgejo > /dev/null
```

Other entrypoints include `ghost`, `monitoring`, `headlamp`, `metallb`, `metrics-server`,
`traefik-dashboard`, `cert-manager/deployment`, and `cert-manager/certificates`.
Remote resources require network access.
Local secret generators require their referenced files.
Rendering to `/dev/null` prevents accidental disclosure of generated Secrets.

For Terraform changes, run these commands from `proxmox-terraform/`:

```sh
terraform fmt -check -diff
terraform validate
```

If providers are absent, initialize the directory with `terraform init -backend=false` before validation.
Preserve the provider lock file unless the task requires dependency changes.
Do not reformat unrelated Terraform files to resolve pre-existing formatting errors.
Run `git diff --check` before completing a change.

## Infrastructure safety

CAUTION: Infrastructure commands can interrupt services or erase persistent data.

- Get explicit approval before applying Kubernetes manifests or Terraform plans.
- Get explicit approval before imports, state changes, VM replacement, node drains, restarts, or resource deletion.
- Before live-cluster commands, verify the Kubernetes context and target namespace.
- Before Proxmox operations, verify the endpoint, node, and VM IDs.
- Keep read-only inspection separate from commands that change infrastructure.
- Treat Terraform plans and cluster diffs as sensitive output.
- Review VM replacement and disk changes before proposing an apply.
- Preserve manually installed K3s services and existing guest data.
- Inspect PV paths, node affinity, PVC bindings, and reclaim policies before storage changes.
- Do not treat a local PV capacity as a filesystem quota.
- Preserve all required members of authoritative Terraform IP sets and firewall rule resources.
- Do not change node names, network addresses, storage paths, or certificate issuers without tracing their consumers.

Local volumes bind data to specific nodes and paths.
Changing scheduling rules alone does not move that data.
Terraform can remove undeclared IP set members or replace VM firewall rules under its management.
