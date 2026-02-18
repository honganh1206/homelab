# HomeLab

## What for?

- Local media streaming
- Learning system administration
- A hobby :)

## Tech Stack (K3s)

### Torrents (`torrents` namespace)

- Radarr — movie management
- Sonarr — TV show management
- Bazarr — subtitle management
- qBittorrent — torrent client

### Media (`media` namespace)

- Plex — media server (hostNetwork for LAN discovery, /dev/dri for hardware transcoding)

### Server (`server` namespace)

- Rustdesk (hbbs + hbbr) — remote desktop server

## Setup

See [SETUP.md](SETUP.md) for the full setup guide including:
- K3s installation
- Migrating existing configs
- Deploying services
- Setting up automated deployment via GitHub Actions

## CI/CD

- **On push to `master`**: GitHub Actions self-hosted runner on the mini PC auto-applies K8s manifests
- **On PR / push**: YAML lint + `kubectl --dry-run` validation runs on GitHub-hosted runners

## Access (NodePort)

| Service      | URL                        |
|--------------|----------------------------|
| qBittorrent  | `http://<mini-pc-ip>:30082` |
| Radarr       | `http://<mini-pc-ip>:30878` |
| Sonarr       | `http://<mini-pc-ip>:30989` |
| Bazarr       | `http://<mini-pc-ip>:30767` |
| Plex         | `http://<mini-pc-ip>:32400` |
| Rustdesk     | hostNetwork (ports 21115-21119) |

## Data Paths

All config data lives under `/home/hong/k8s-data/<namespace>/<service>/config`.

Media libraries mount directly from `/home/hong/Media/SeagateExpansion/Torrents/`.
