# NixOS GitHub Actions Workflows

This directory contains GitHub Actions workflows for managing your NixOS server deployment and maintenance.

## Workflows Overview

### 1. `nixos-rebuild.yml` - Automatic System Rebuilds
**Trigger**: Automatically runs when `flake.nix` or `disko.nix` files are pushed to the main branch.

**Features**:
- Validates flake syntax before building
- Performs dry-run to catch issues early
- Tests configuration before switching
- Verifies critical services after rebuild
- Automatic cleanup of old generations
- Updates flake.lock file
- Rollback capability via manual trigger

**Manual Usage**:
```bash
# Trigger via GitHub web interface:
# Actions -> NixOS System Rebuild -> Run workflow
# Options:
# - force_rebuild: true/false
# - rollback: true/false (rolls back to previous generation)
```

### 2. `nixos-maintenance.yml` - System Maintenance
**Trigger**: Manual only via GitHub Actions web interface.

**Operations Available**:
- `update-flake`: Updates all flake inputs and commits changes
- `cleanup-generations`: Removes old system generations (configurable)
- `rebuild-boot`: Updates boot configuration without switching
- `check-health`: Comprehensive system health check
- `optimize-store`: Optimizes Nix store and garbage collection

**Usage**:
```bash
# Go to Actions -> NixOS Maintenance -> Run workflow
# Select operation and configure options
```

### 3. `nixos-emergency-rollback.yml` - Emergency Rollback
**Trigger**: Manual only, for emergency situations.

**Features**:
- Quick rollback to previous or specific generation
- Requires confirmation ("ROLLBACK") to prevent accidents
- Verifies system state after rollback
- Checks critical services

**Usage**:
```bash
# Actions -> NixOS Emergency Rollback -> Run workflow
# Enter "ROLLBACK" in confirmation field
# Optionally specify generation number
```

## Workflow Security

### Prerequisites
1. **Self-hosted runners**: These workflows require self-hosted GitHub runners on your NixOS system
2. **Sudo access**: The runner user needs sudo privileges for nixos-rebuild commands
3. **Git access**: Runners need access to commit flake.lock updates

### Runner Configuration
Your flake.nix already includes GitHub runner configuration. Ensure the token file exists:
```bash
sudo mkdir -p /var/lib/github-runner
echo "YOUR_GITHUB_TOKEN" | sudo tee /var/lib/github-runner/token
sudo chown github-runner:github-runner /var/lib/github-runner/token
sudo chmod 600 /var/lib/github-runner/token
```

## Safety Features

### Automatic Rollback Conditions
- Build failures automatically show rollback instructions
- Critical service verification after each rebuild
- Timeout protection (30 minutes for rebuilds)

### Pre-deployment Checks
- Flake syntax validation
- Dry-run builds to catch issues
- Configuration testing before activation

### Generation Management
- Automatic cleanup of old generations (keeps last 5)
- Manual cleanup with configurable retention
- Generation tracking for easy rollbacks

## Monitoring and Notifications

### Build Status
Monitor workflow status in the GitHub Actions tab. Failed builds include:
- Clear error messages
- Rollback instructions
- Recovery procedures

### System Health
Use the `check-health` maintenance operation to monitor:
- System resources
- Service status
- Docker containers
- Network connectivity
- Recent error logs

## Best Practices

### 1. Testing Changes
Before pushing flake changes:
```bash
cd infra
nix flake check
nixos-rebuild dry-build --flake .#myserver
```

### 2. Gradual Rollouts
For major changes:
1. Use `rebuild-boot` operation first
2. Reboot manually to test
3. If successful, push to trigger full rebuild

### 3. Emergency Procedures
If system becomes unresponsive:
1. Access via console/KVM
2. Run manual rollback: `sudo nixos-rebuild switch --rollback`
3. Or use emergency rollback workflow if GitHub access available

### 4. Regular Maintenance
Schedule regular maintenance:
- Weekly: `update-flake` to get security updates
- Monthly: `cleanup-generations` to free space
- Monthly: `optimize-store` to reduce disk usage
- Daily: `check-health` for monitoring

## Troubleshooting

### Common Issues

#### Build Failures
1. Check flake syntax: `nix flake check`
2. Review error logs in GitHub Actions
3. Test locally before pushing
4. Use rollback if system is affected

#### Runner Issues
1. Check runner status: `systemctl status github-runner-*`
2. Verify token: `sudo cat /var/lib/github-runner/token`
3. Check runner logs: `journalctl -u github-runner-*`

#### Network Issues
1. Verify Tailscale: `tailscale status`
2. Check firewall: `sudo iptables -L`
3. Test connectivity: `ping 8.8.8.8`

### Recovery Scenarios

#### Scenario 1: Bad Configuration Pushed
1. Use emergency rollback workflow
2. Fix configuration locally
3. Test thoroughly before pushing

#### Scenario 2: Runner Offline
1. Access system directly
2. Manual rollback: `sudo nixos-rebuild switch --rollback`
3. Fix runner configuration
4. Restart runners: `sudo systemctl restart github-runner-*`

#### Scenario 3: System Won't Boot
1. Boot from previous generation in GRUB menu
2. Fix configuration
3. Rebuild manually
4. Update repository with fix

## Configuration Files

### Workflow Files
- `nixos-rebuild.yml` - Main rebuild workflow
- `nixos-maintenance.yml` - Maintenance operations
- `nixos-emergency-rollback.yml` - Emergency rollback

### Key Settings
- Timeout: 30 minutes for rebuilds
- Generation retention: 5 generations (configurable)
- Health checks: SSH, Docker, Tailscale
- Cleanup schedule: 14 days for garbage collection