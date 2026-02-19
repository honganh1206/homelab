# Mini PC Setup Guide

## Prerequisites

- Mini PC running Pop!_OS / Ubuntu (user: `hong`)
- SSH access from your client machine
- GitHub account with this repo pushed to it

---

## Step 1: Install K3s

```bash
# SSH into the mini PC
ssh minipc

# Make kubeconfig readable so the GitHub Actions runner can use kubectl
sudo mkdir -p /etc/rancher/k3s
echo 'write-kubeconfig-mode: "0644"' | sudo tee /etc/rancher/k3s/config.yaml

# Install K3s (picks up config.yaml automatically)
curl -sfL https://get.k3s.io | sh -

# Verify installation
sudo kubectl get nodes

# Allow your user to run kubectl without sudo
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Verify
kubectl get nodes
```

## Step 2: Create data directories

```bash
mkdir -p /home/hong/k8s-data/torrents/qbittorrent/config
mkdir -p /home/hong/k8s-data/torrents/radarr/config
mkdir -p /home/hong/k8s-data/torrents/sonarr/config
mkdir -p /home/hong/k8s-data/torrents/bazarr/config
mkdir -p /home/hong/k8s-data/media/plex/config
mkdir -p /home/hong/k8s-data/server/rustdesk/data
mkdir -p /home/hong/k8s-data/tools/homepage/config
mkdir -p /home/hong/k8s-data/infra/pihole/etc-pihole
mkdir -p /home/hong/k8s-data/infra/pihole/etc-dnsmasq.d
```

## Step 3: Migrate existing configs

If you have existing local installations, copy their configs before deploying:

```bash
# qBittorrent (adjust source path if different)
cp -r ~/.config/qBittorrent/* /home/hong/k8s-data/torrents/qbittorrent/config/

# Radarr
cp -r ~/.config/Radarr/* /home/hong/k8s-data/torrents/radarr/config/

# Sonarr
cp -r ~/.config/Sonarr/* /home/hong/k8s-data/torrents/sonarr/config/

# Bazarr
cp -r ~/.config/bazarr/* /home/hong/k8s-data/torrents/bazarr/config/

# Plex (usually in /var/lib/plexmediaserver)
sudo cp -r /var/lib/plexmediaserver/Library /home/hong/k8s-data/media/plex/config/
sudo chown -R hong:hong /home/hong/k8s-data/media/plex/config/

# Rustdesk (from existing Docker setup)
cp -r ~/mini-pc-docker-compose-yml/assets/server_management/rustdesk/data/* /home/hong/k8s-data/server/rustdesk/data/
```

## Step 4: Set up the GitHub Actions self-hosted runner

Do this **before** deploying any services. The runner lets you deploy by simply pushing code — no need to clone the repo or manually run commands on the mini PC.

> ⚠️ **Important:** Make sure your GitHub repo is **private**. GitHub recommends only using
> self-hosted runners with private repos, since forks of public repos could run arbitrary
> code on your machine. See [Secure use reference](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners).

### 4a. Get the registration token from GitHub

1. Go to your GitHub repo → **Settings** → **Actions** → **Runners**
2. Click **New self-hosted runner**
3. Select **Linux** and **x64**
4. GitHub will display a page with commands and a **time-limited registration token** (expires in 1 hour) — keep this page open

### 4b. Install the runner on the mini PC

SSH into the mini PC and run:

```bash
# Create a folder
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download the latest runner package (v2.331.0 as of Feb 2026)
curl -O -L https://github.com/actions/runner/releases/download/v2.331.0/actions-runner-linux-x64-2.331.0.tar.gz

# (Optional) Verify the checksum
echo "5fcc01bd546ba5c3f1291c2803658ebd3cedb3836489eda3be357d41bfcf28a7  actions-runner-linux-x64-2.331.0.tar.gz" | shasum -a 256 -c

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.331.0.tar.gz
```

> **Note:** GitHub may show a newer version on the setup page. If so, use that URL instead.

### 4c. Configure the runner

```bash
# Use the token from the GitHub setup page (step 4a)
./config.sh --url https://github.com/<your-user>/<your-repo> --token <TOKEN>
```

When prompted:
- **Runner group:** press Enter for default
- **Runner name:** press Enter (uses hostname) or type a name like `minipc`
- **Labels:** press Enter for default (uses `self-hosted,Linux,X64`)
- **Work folder:** press Enter for default (`_work`)

### 4d. Install as a systemd service

This ensures the runner starts automatically on boot and survives reboots:

```bash
# Install the service
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Verify it's running
sudo ./svc.sh status
```

### 4e. Verify on GitHub

Go back to your GitHub repo → **Settings** → **Actions** → **Runners**.
Your runner should appear with a green **Online** status.

### How it works

```
You push code → GitHub Actions triggers → Self-hosted runner on mini PC picks it up
→ Runs `actions/checkout` (auto-clones repo) → Runs helm upgrade --install → Services updated
```

No manual repo clone. No SSH to pull. No cron jobs. Changes deploy within seconds of pushing.

### Managing the runner service

```bash
cd ~/actions-runner

sudo ./svc.sh status    # check status
sudo ./svc.sh stop      # stop the runner
sudo ./svc.sh start     # start the runner
sudo ./svc.sh uninstall # remove the service
```

## Step 5: Stop local services and deploy

Stop each service **one at a time** as you migrate (not all at once).

For each service: stop it locally, then push the corresponding K8s manifest to `master` from your client machine. The self-hosted runner will auto-deploy it.

```bash
# Example: stop qBittorrent before deploying the K8s version
sudo systemctl disable --now qbittorrent-nox

# After verifying the K8s version works, proceed to the next service
sudo systemctl disable --now radarr
sudo systemctl disable --now sonarr
sudo systemctl disable --now bazarr
sudo systemctl disable --now plexmediaserver
```

## Step 6: Verify each service

| Service     | Check URL                          | What to verify                              |
|-------------|------------------------------------|---------------------------------------------|
| qBittorrent | `http://<mini-pc-ip>:30082`        | Web UI loads, existing torrents appear       |
| Radarr      | `http://<mini-pc-ip>:30878`        | Movies library intact, qBit connection works |
| Sonarr      | `http://<mini-pc-ip>:30989`        | Shows library intact, qBit connection works  |
| Bazarr      | `http://<mini-pc-ip>:30767`        | Subtitle settings preserved                  |
| Plex        | `http://<mini-pc-ip>:32400/web`    | Libraries visible, playback works            |
| Rustdesk    | Connect via Rustdesk client        | Remote access still works                    |
| Homepage    | `http://<mini-pc-ip>:30300`        | Dashboard loads, can add service widgets     |
| IT-Tools    | `http://<mini-pc-ip>:30080`        | Tools page loads                             |
| Pi-hole     | `http://<mini-pc-ip>:30053/admin`  | Admin dashboard loads, DNS resolves          |
| Samba       | `\\<mini-pc-ip>\Media` via explorer | Shared folders visible                       |

### Post-deploy: Update Radarr/Sonarr download client

After migrating qBittorrent to K3s, update the download client URL in Radarr and Sonarr:

- **Old:** `localhost:8082` or `127.0.0.1:8082`
- **New:** `qbittorrent.torrents.svc.cluster.local:8080`

---

## Useful commands

```bash
# See all pods across namespaces
kubectl get pods -A

# Check logs for a service
kubectl logs -n torrents deployment/radarr

# Restart a service after config change
kubectl rollout restart -n torrents deployment/radarr

# See events (useful for debugging)
kubectl get events -n torrents --sort-by='.lastTimestamp'

# Deploy / update all services
helm upgrade --install homelab helm/homelab --create-namespace

# Preview what Helm will render
helm template homelab helm/homelab

# Disable a service (set enabled: false in values.yaml, then redeploy)
helm upgrade --install homelab helm/homelab

# Uninstall everything
helm uninstall homelab
```
