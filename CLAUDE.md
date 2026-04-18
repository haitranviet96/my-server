# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**my-server** is a self-hosted infrastructure project that manages a personal data center using NixOS. It combines declarative system configuration with containerized microservices, supporting both bare-metal infrastructure management and Docker-based application deployments.

**Remote:** https://github.com/haitranviet96/my-server

## Architecture Overview

The project has three main layers:

### 1. Infrastructure Layer (`/infra`)
- **NixOS Flake Configuration** (`flake.nix`, `disko.nix`)
  - Declarative system configuration using Nix ecosystem
  - Modular design with individual Nix modules for hardware, networking, storage, users, virtualization, and programs
  - State version: NixOS 25.11
  
- **Key System Modules:**
  - `hardware.nix`: NVIDIA GPU setup with CUDA support, power management, kernel parameters for IOMMU/VFIO
  - `networking.nix`: SSH (key-only auth, no passwords), Tailscale VPN, firewall rules, network bridges for KVM/QEMU VMs
  - `virtualization.nix`: Docker engine with 3 bridge networks (multimedia, webserver, tools), KVM/libvirtd configuration
  - `storage/flake.nix`: Btrfs filesystem management with automatic snapshot creation and retention policies
  - `storage/btrbk.conf`: Incremental btrfs backups (daily at 2am) and Google Drive sync (daily at 3am)
  - `github-runners.nix`: 3 self-hosted GitHub Actions runners with ephemeral cleanup, resource limits, and Docker/CUDA support
  - `ups.nix`: CyberPower UPS monitoring via NUT server (port 3493)
  - `programs.nix`: System packages including rclone, btrbk, sops, age (secrets), claude-code, Google Cloud SDK
  - `users.nix`: haitv user, github-runner system user, deploy user with sudo NOPASSWD for nixos-rebuild

- **Installation/Deployment:**
  - `install.sh`: Local installation using disko-install
  - `remote-install.sh`: Remote deployment via nixos-anywhere with SSH setup, optional GitHub PAT, optional btrfs home folder migration

### 2. Services Layer (`/services`)
Each service is a Docker Compose application with its own directory containing:
- `compose.yml`: Docker Compose configuration
- `config.env`: Service-specific environment variables (SOPS-encrypted)
- Optional `Dockerfile`, `Caddyfile`, or additional configs

**Deployed Services (25 total):**
- **Multimedia:** Jellyfin, Jellyseerr, Bazarr, Radarr, Sonarr, Prowlarr, qBittorrent, Frigate
- **Media Management:** Immich (photo library with ML, PostgreSQL + Redis, hardware-accelerated transcoding via NVIDIA)
- **Monitoring/Analytics:** Uptime Kuma, Netdata, Glances, Scrutiny, WUD (docker update checker)
- **File Management:** FileBrowser, Czkawka (duplicate finder)
- **Web/Reverse Proxy:** Caddy (custom Dockerfile, Caddyfile config)
- **Authentication/Security:** Vaultwarden (password manager)
- **Infrastructure:** Portainer (Docker management)
- **CMS:** Ghost CMS
- **System Tools:** Ollama (LLMs), Speedtest Tracker
- **Customization:** Homepage (git submodule, custom deploy workflow)
- **Virtualization:** Windows 11 VM (KVM/QEMU passthrough)

**Docker Networks:**
- `multimedia`: Media apps and torrent clients
- `webserver`: Caddy reverse proxy and web services
- `tools`: Monitoring, file management, security services

### 3. Secrets & CI/CD Layer
- **SOPS-NixOS Integration:** Uses age/gpg encryption for secrets with `.sops.yaml` defining age keys
- **GitHub Actions Workflows:** 20 workflow files in `.github/workflows/`
  - `nixos-rebuild.yml`: Auto-deploy system changes when `/infra/**` changes
  - Service-specific workflows (e.g., `caddy.yml`, `immich.yml`, `homepage.yml`): Auto-deploy on service changes
  - Custom GitHub Actions in `.github/actions/`:
    - `sops-decode`: Decrypts SOPS-encrypted config files before deployment
    - `deploy`: Generic Docker Compose deploy action
- **Self-Hosted Runners:** Use ephemeral runners with automatic cleanup via serviceOverrides

## Directory Structure

```
my-server/
├── infra/                          # NixOS system configuration
│   ├── flake.nix                   # Flake outputs and module imports
│   ├── disko.nix                   # Disk partitioning (Btrfs with subvolumes)
│   ├── modules/                    # Individual system modules
│   │   ├── hardware.nix
│   │   ├── networking.nix
│   │   ├── virtualization.nix
│   │   ├── storage/                # Btrfs backup/snapshot config
│   │   ├── github-runners.nix
│   │   ├── ups.nix
│   │   ├── programs.nix
│   │   ├── users.nix
│   │   └── home-haitv.nix
│   ├── install.sh                  # Local installation script
│   ├── remote-install.sh           # Remote deployment via nixos-anywhere
│   └── DEPLOYMENT-CHECKLIST.md     # Pre-deployment requirements (GitHub PAT, SSH keys)
├── services/                       # Docker Compose microservices (25 services)
│   ├── caddy/                      # Reverse proxy (custom Dockerfile)
│   ├── immich/                     # Photo library (NVIDIA ML + transcoding)
│   ├── jellyfin/
│   ├── vaultwarden/
│   ├── homepage/                   # Git submodule
│   └── [20+ other services]
├── scripts/
│   ├── backup/
│   │   └── gdrive-sync.sh          # Daily Google Drive sync for backups
│   └── recreate-network.sh
├── .github/
│   ├── workflows/                  # 20 GitHub Actions workflows
│   │   ├── nixos-rebuild.yml
│   │   └── [19 service deployment workflows]
│   └── actions/                    # Custom GitHub Actions
│       ├── deploy/
│       └── sops-decode/
├── .sops.yaml                      # SOPS age key configuration
├── .gitmodules                     # Homepage submodule
├── .gitignore
└── CLAUDE.md                       # This file
```

## Key Technologies & Integrations

- **NixOS/Nix Flakes:** Reproducible, declarative system configuration
- **Btrfs:** Root filesystem with snapshots, compression, incremental backups
- **Docker & Docker Compose:** Service containerization and orchestration
- **Caddy:** Reverse proxy with auto TLS
- **SOPS (Mozilla Secrets):** Encrypted configuration management (age/gpg)
- **NVIDIA CUDA:** GPU acceleration for Immich ML/transcoding
- **KVM/QEMU:** Hardware passthrough for Windows 11 VM
- **GitHub Actions:** CI/CD with self-hosted ephemeral runners
- **Tailscale:** VPN for remote access
- **NUT (Network UPS Tools):** UPS monitoring and management
- **rclone:** Google Drive syncing for backups
- **Systemd Timers:** Scheduled tasks (backups, NixOS garbage collection)

## Common Workflows & Commands

### NixOS System Configuration

**Validate and test configuration locally (if on NixOS):**
```bash
cd infra
nix flake check
```

**Deploy system configuration changes to remote server:**
- Automatically triggered by GitHub Actions when changes to `/infra/**` are pushed
- Or manually via SSH:
  ```bash
  ssh deploy@<server> sudo nixos-rebuild switch --flake "github:haitranviet96/my-server?dir=infra#myserver"
  ```

**Initial remote installation:**
```bash
cd infra
./remote-install.sh <target-host> [OPTIONS]
```
- Requires `gh_pat` file in current or home directory (GitHub PAT for Actions runners)
- Optional: `--github-pat`, `--copy-home`, `--old-home-device` flags for advanced setup
- See `DEPLOYMENT-CHECKLIST.md` for pre-deployment requirements

### Service Deployment

**Deploy a single service (automated via GitHub Actions):**
- Push changes to `/services/<service-name>/` → workflow auto-triggers
- Manual deployment:
  ```bash
  cd services/<service-name>
  docker compose down
  docker compose up -d --build
  ```

**Decrypt and view encrypted config:**
```bash
cd services/<service-name>
sops -d config.env
```

**Update service configuration:**
- Edit `config.env` or `compose.yml`
- Commit and push → GitHub Action handles deployment
- Uses SOPS to decrypt `config.env` before Docker Compose launch

**View service logs:**
```bash
cd services/<service-name>
docker compose logs -f
```

**Recreate Docker networks (if corrupted):**
```bash
./scripts/recreate-network.sh
```

### Storage & Backups

**Btrfs snapshots** are created automatically daily (systemd timer) and retained per btrbk config:
- Root (/): 7 days minimum
- Home (/home): 7 days local + 7d/3w/1m external to /media/BackupDisk
- Data (/media/Data): 7 days local + 7d/3w/3m external

**Trigger backup manually:**
```bash
sudo systemctl start btrbk
sudo systemctl start gdrive-backup
```

**Restore from snapshot:**
```bash
# List snapshots
btrfs subvolume list -s /
# Rollback (requires reboot into snapshot)
sudo btrfs subvolume snapshot /path/to/snapshot /.old
```

### Secrets Management

**Create/encrypt new secrets with SOPS:**
```bash
sops /path/to/new-config.env
# $EDITOR will open; SOPS auto-encrypts on save using .sops.yaml keys
```

**Re-encrypt all files after changing age keys:**
```bash
sops updatekeys -y services/**/*.env
```

**GitHub Action Secrets Setup:**
- `SSH_HOST`, `SSH_USERNAME`, `SSH_PRIVATE_KEY`: For nixos-rebuild and service deployments
- `GPG_PRIVATE_KEY`: For SOPS decryption in Actions (base64-encoded, stored at `/var/lib/github-runner/gpg-key.b64` on runners)

### Monitoring & Debugging

**SSH into server via Tailscale:**
```bash
tailscale ip -4 <server-hostname>
ssh haitv@<tailscale-ip>
```

**Monitor system resources:**
```bash
# On server via SSH
btop  # btop-cuda for GPU monitoring
glances http://<server>:61208
netdata http://<server>:19999
```

**Check UPS status:**
```bash
upsc cyberpower@localhost
# Or via HTTP:
# upsd listening on <server>:3493
```

**Verify GitHub runners:**
```bash
# On server
systemctl status github-runners-*.service
docker ps | grep github-runner
```

## Important Conventions & Patterns

### Service Configuration Pattern
1. Each service has a `compose.yml` with environment references
2. Environment variables split across:
   - `docker.env` (shared defaults for all services)
   - `config.env` (service-specific, SOPS-encrypted)
   - `.local.env` (optional local overrides, git-ignored)
3. Volumes typically mount to `/home/haitv/.config/`, `/home/haitv/.cache/`, or mounted external disks
4. Services use named Docker networks (multimedia, webserver, tools) for inter-service communication
5. Caddy reverse proxy bridges external traffic to internal service ports

### Nix Module Pattern
- Each module is a function returning a Nix attribute set
- Module files imported in `flake.nix` main modules list
- Conditional features use `lib` helpers (e.g., `lib.mkForce` for overrides)
- Secrets stored in `/etc/nixos/secrets/` (age-encrypted in deployment)
- Systemd services/timers follow NixOS conventions

### GitHub Actions Patterns
- Workflows trigger on path changes (not full repo rebuilds)
- All service deployments use `runs-on: self-hosted` (ephemeral runners)
- SOPS decryption happens before Docker Compose launch
- Immich workflow manually sets `.env` from `config.env` (other services use action)
- Homepage is a git submodule with separate workflow

### Secrets & Encryption
- `.sops.yaml` defines age keys for different recipients (mydinhdc, macbook)
- All `.env` files are encrypted with SOPS
- GitHub runner servers must have `/var/lib/github-runner/gpg-key.b64` for decryption
- Local development can use GPG key or age keys via `SOPS_AGE_KEY_FILE` env var

## NixOS Flake Inputs

- **nixpkgs**: nixos-unstable channel for latest packages
- **disko**: Declarative disk partitioning and formatting
- **home-manager**: User environment management (integrated with haitv module)
- **sops-nix**: SOPS integration for secrets management

## Hardware & Deployment Notes

- **Disk:** `/dev/vda` (configurable, can be `/dev/sda` or `/dev/nvme0n1`)
- **Boot:** UEFI + systemd-boot + Btrfs root with 6 subvolumes
- **GPU:** NVIDIA RTX (open-source kernel module), CUDA support for Docker + Immich
- **UPS:** CyberPower CP1500 AVR (USB connection, NUT monitoring)
- **Timezone:** Asia/Bangkok
- **External Disks:** Multiple Btrfs volumes (/media/Data, /media/BackupDisk, /media/OLDROOT, /media/OLDHOME)
- **VM Guest:** Windows 11 via KVM/QEMU with optional GPU passthrough (commented out in hardware.nix)

## Troubleshooting Common Issues

**GitHub Actions runner won't authenticate:**
- Verify `/var/lib/github-runner/token` exists with valid GitHub PAT
- Check `/var/lib/github-runner/gpg-key.b64` is base64-encoded private GPG key
- Runner logs: `journalctl -u github-runners-runner-1.service -f`

**SOPS decryption fails in Actions:**
- Ensure `gpg-key.b64` is properly base64-encoded and contains the full private key
- Test locally: `sops -d services/<service>/config.env`

**Docker networks unavailable:**
- Run `./scripts/recreate-network.sh` to recreate multimedia, webserver, tools networks
- Check `/var/lib/github-runner/token` and verify docker socket permissions

**Immich hardware acceleration not working:**
- Verify NVIDIA drivers installed: `nvidia-smi`
- Check `hwaccel.transcoding.yml` and `hwaccel.ml.yml` for correct CUDA references
- Immich service must run on machine with GPU access

**Btrfs backups not running:**
- Verify `/media/BackupDisk` is mounted: `mount | grep BackupDisk`
- Check btrbk timer: `systemctl status btrbk.timer`
- Manual trigger: `sudo systemctl start btrbk`

**NixOS rebuild fails:**
- Check flake syntax: `nix flake check`
- Review system logs: `journalctl -xeu nixos-rebuild.service`
- Rollback to previous generation: `sudo nixos-rebuild switch --rollback`
