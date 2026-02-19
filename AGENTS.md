# AGENTS.md

## Overview
Homelab K3s infrastructure repo. Kubernetes manifests are managed via a Helm chart under `helm/homelab/`. Legacy raw manifests remain under `k8s/` for reference. No application code — only YAML manifests and Helm templates.

## Lint / Validate
- **Lint chart:** `helm template homelab helm/homelab | kubeconform -summary -strict`
- **Template preview:** `helm template homelab helm/homelab`
- **Dry-run install:** `helm install homelab helm/homelab --dry-run`
- **Deploy (manual):** `helm upgrade --install homelab helm/homelab --create-namespace`

## CI/CD
- Push to `master` runs kubeconform lint on rendered Helm templates (GitHub-hosted runner).
- `workflow_dispatch` deploys to K3s via `helm upgrade --install` on self-hosted runner on the mini PC.

## Structure
- `helm/homelab/Chart.yaml` — chart metadata
- `helm/homelab/values.yaml` — centralized config (host paths, ports, images, env vars)
- `helm/homelab/templates/` — templated manifests for all services
- Config data on host: `/home/hong/k8s-data/<namespace>/<service>/config`
- Media on host: `/home/hong/Media/SeagateExpansion/Torrents/` and `.../WesternDigital/Torrents/`

## Conventions
- Use 2-space indentation in YAML. Follow standard Kubernetes manifest structure.
- Images use `lscr.io/linuxserver/*` where available. Set `PUID=1000`, `PGID=1000`, `TZ=Etc/UTC` via `values.yaml`.
- Expose services via `NodePort` (30000+ range). Keep one template per service.
- All host paths are centralized in `values.yaml` under `paths.*` — never hardcode paths in templates.
- Each service has an `enabled` flag in values.yaml for easy toggling.
- When adding a new service, also register it in `values.yaml` under `homepage.services` so it appears on the Homepage dashboard.
- Secrets/env files are gitignored (`*.env`). Never commit credentials.
