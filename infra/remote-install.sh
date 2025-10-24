#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Remote NixOS Installation Script with SSH Setup
# Uses nixos-anywhere to remotely install predefined NixOS configuration
# ==============================================================================

# === Color codes for output ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Helper functions ===
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# === Configuration variables ===
TARGET_HOST=""
TARGET_USER="root"
TARGET_DISK="/dev/vda"
SSH_KEY_PATH=""
SSH_CONFIG_HOST=""
USE_SSH_CONFIG=false
FLAKE_CONFIG="myserver"
NIXOS_USERNAME="haitv"
GITHUB_PAT=""
COPY_HOME=false
OLD_HOME_DEVICE=""
OLD_HOME_BTRFS_MOUNT="/mnt/old_btrfs"  # Internal mount point for old btrfs disk

# === Usage function ===
usage() {
    cat << EOF
Usage: $0 [OPTIONS] TARGET_HOST

Remote NixOS installation with SSH setup using nixos-anywhere.
Prioritizes SSH config > key file > manual setup for authentication.

ARGUMENTS:
  TARGET_HOST     IP address, hostname, or SSH config host alias

OPTIONS:
  -u, --user      SSH user for initial connection (default: root, or from SSH config)
  -d, --disk      Target disk device (default: /dev/vda)
  -k, --key       SSH private key path (default: auto-detect or from SSH config)
  -f, --flake     Flake configuration name (default: myserver)
  --nixos-user    NixOS username (default: haitv)
  --github-pat    GitHub Personal Access Token (will be saved to /var/lib/github-runner/token)
  --copy-home     Copy existing home folder from old btrfs @home subvolume
  --old-home-device  Device with old btrfs disk (e.g., /dev/sdb1)
  -h, --help      Show this help message

EXAMPLES:
  $0 myserver-host              # Use SSH config entry, prompt for all config
  $0 192.168.1.100              # Auto-detect key or prompt for setup
  $0 -k ~/.ssh/custom_key 192.168.1.100
  $0 -u installer -d /dev/sda myserver
  $0 --github-pat "ghp_xxx" myserver
  $0 --copy-home --old-home-device /dev/sdb1 myserver
  $0 --nixos-user myuser myserver-host

AUTHENTICATION PRIORITY:
  1. SSH config host (if TARGET_HOST matches ~/.ssh/config entry)
  2. Specified key file (-k option)
  3. Default key files (~/.ssh/id_ed25519, ~/.ssh/id_rsa)
  4. Manual setup prompt

PREREQUISITES:
  1. Target machine should be booted from NixOS minimal ISO
  2. SSH access should be available on target machine
  3. nixos-anywhere should be available (will be installed if missing)
  4. Flake configuration should be present in current directory

EOF
}

# === Parse command line arguments ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -d|--disk)
                TARGET_DISK="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY_PATH="$2"
                shift 2
                ;;
            -f|--flake)
                FLAKE_CONFIG="$2"
                shift 2
                ;;
            --nixos-user)
                NIXOS_USERNAME="$2"
                shift 2
                ;;
            --github-pat)
                GITHUB_PAT="$2"
                shift 2
                ;;
            --copy-home)
                COPY_HOME=true
                shift
                ;;
            --old-home-device)
                OLD_HOME_DEVICE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_HOST" ]]; then
                    TARGET_HOST="$1"
                else
                    log_error "Multiple hosts specified. Only one target host is allowed."
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Target host is required"
        usage
        exit 1
    fi
}

# === Search for files in multiple locations ===
search_file_in_locations() {
    local file_name="$1"
    local search_locations=(
        "$(pwd)/$file_name"                    # Current folder
        "$HOME/$file_name"                     # Current home
    )
    
    for location in "${search_locations[@]}"; do
        if [[ -f "$location" ]]; then
            echo "$location"
            return 0
        fi
    done
    
    return 1
}

# === Check GitHub PAT file ===
check_github_pat() {
    log_info "Checking for GitHub PAT file..."
    
    # If already provided via command line, use it
    if [[ -n "$GITHUB_PAT" ]]; then
        log_success "GitHub PAT provided via command line"
        return 0
    fi
    
    # Search for gh_pat file in common locations
    local pat_file
    pat_file=$(search_file_in_locations "gh_pat")
    
    if [[ -n "$pat_file" ]]; then
        log_success "Found GitHub PAT file at: $pat_file"
        GITHUB_PAT=$(cat "$pat_file")
        if [[ -z "$GITHUB_PAT" ]]; then
            log_error "GitHub PAT file is empty: $pat_file"
            return 1
        fi
        return 0
    fi
    
    # Not found in any location
    log_error "GitHub PAT file not found in:"
    log_error "  - Current folder: ./gh_pat"
    log_error "  - Home folder: $HOME/gh_pat"
    log_error ""
    log_error "Please create the file with your GitHub PAT and try again."
    log_error "Usage: echo 'ghp_xxx' > ./gh_pat or echo 'ghp_xxx' > ~/$HOME/gh_pat"
    return 1
}

# === Prompt for required configuration ===
prompt_for_configuration() {
    log_info "Collecting configuration information..."
    echo

    # Prompt for TARGET_USER if default is still set
    read -p "SSH user for initial connection (default: $TARGET_USER): " input_user
    if [[ -n "$input_user" ]]; then
        TARGET_USER="$input_user"
    fi

    # Prompt for TARGET_DISK
    read -p "Target disk device (default: $TARGET_DISK): " input_disk
    if [[ -n "$input_disk" ]]; then
        TARGET_DISK="$input_disk"
    fi

    # Prompt for FLAKE_CONFIG
    read -p "Flake configuration name (default: $FLAKE_CONFIG): " input_flake
    if [[ -n "$input_flake" ]]; then
        FLAKE_CONFIG="$input_flake"
    fi

    # Prompt for NIXOS_USERNAME
    read -p "NixOS username (default: $NIXOS_USERNAME): " input_nixos_user
    if [[ -n "$input_nixos_user" ]]; then
        NIXOS_USERNAME="$input_nixos_user"
    fi

    # Prompt for home folder copy
    if [[ "$COPY_HOME" != "true" ]]; then
        read -p "Copy home folder from old btrfs @home subvolume? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            COPY_HOME=true
            read -p "Old btrfs disk device (e.g., /dev/sdb1): " OLD_HOME_DEVICE
            if [[ -z "$OLD_HOME_DEVICE" ]]; then
                log_error "Device path is required for home folder copy"
                COPY_HOME=false
            fi
        fi
    fi

    echo
}

# === SSH configuration detection ===
detect_ssh_config() {
    local host="$1"
    local ssh_config_file="$HOME/.ssh/config"
    
    if [[ -f "$ssh_config_file" ]]; then
        # Check if host exists in SSH config
        if ssh -F "$ssh_config_file" -G "$host" >/dev/null 2>&1; then
            local config_output
            config_output=$(ssh -F "$ssh_config_file" -G "$host" 2>/dev/null)
            
            # Extract hostname, user, and identity file from SSH config
            local config_hostname config_user config_key
            config_hostname=$(echo "$config_output" | grep "^hostname " | awk '{print $2}')
            config_user=$(echo "$config_output" | grep "^user " | awk '{print $2}')
            config_key=$(echo "$config_output" | grep "^identityfile " | awk '{print $2}' | head -1)
            
            # Expand tilde in key path
            if [[ "$config_key" =~ ^~/ ]]; then
                config_key="${config_key/#\~/$HOME}"
            fi
            
            # Check if this looks like a real config entry (not just defaults)
            if [[ "$config_hostname" != "$host" ]] || [[ -n "$config_user" && "$config_user" != "root" ]] || [[ -f "$config_key" ]]; then
                log_success "Found SSH config entry for '$host'"
                log_info "  Hostname: ${config_hostname:-$host}"
                log_info "  User: ${config_user:-$TARGET_USER}"
                if [[ -f "$config_key" ]]; then
                    log_info "  Key: $config_key"
                fi
                
                SSH_CONFIG_HOST="$host"
                USE_SSH_CONFIG=true
                
                # Update target host to actual hostname if specified in config
                if [[ -n "$config_hostname" && "$config_hostname" != "$host" ]]; then
                    TARGET_HOST="$config_hostname"
                fi
                
                # Update user if specified in config and not overridden by command line
                if [[ -n "$config_user" && "$TARGET_USER" == "root" ]]; then
                    TARGET_USER="$config_user"
                fi
                
                # Set key file if found in config and not specified via command line
                if [[ -f "$config_key" && -z "$SSH_KEY_PATH" ]]; then
                    SSH_KEY_PATH="$config_key"
                fi
                
                return 0
            fi
        fi
    fi
    
    return 1
}

# === SSH key detection ===
detect_ssh_key() {
    if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
        log_success "Using specified SSH key: $SSH_KEY_PATH"
        return 0
    fi
    
    # Try common key locations
    local key_candidates=(
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_rsa"
        "$HOME/.ssh/id_ecdsa"
    )
    
    for key in "${key_candidates[@]}"; do
        if [[ -f "$key" ]]; then
            log_success "Found SSH key: $key"
            SSH_KEY_PATH="$key"
            return 0
        fi
    done
    
    return 1
}

# === Manual SSH setup ===
setup_manual_ssh() {
    log_warning "No SSH key found or SSH config entry detected"
    log_info "Manual SSH setup required"
    
    echo "Please choose an option:"
    echo "1. Generate a new SSH key pair"
    echo "2. Specify path to existing SSH key"
    echo "3. Use password authentication (not recommended)"
    echo "4. Exit"
    
    read -p "Enter your choice [1-4]: " choice
    
    case $choice in
        1)
            local key_path="$HOME/.ssh/id_ed25519_nixos"
            log_info "Generating new SSH key at $key_path"
            ssh-keygen -t ed25519 -f "$key_path" -N ""
            SSH_KEY_PATH="$key_path"
            
            log_info "Public key generated:"
            cat "${key_path}.pub"
            log_warning "You need to add this public key to the target machine's authorized_keys"
            read -p "Press Enter after you've added the public key to the target machine..."
            ;;
        2)
            read -p "Enter path to SSH private key: " key_path
            if [[ -f "$key_path" ]]; then
                SSH_KEY_PATH="$key_path"
                log_success "Using SSH key: $SSH_KEY_PATH"
            else
                log_error "Key file not found: $key_path"
                return 1
            fi
            ;;
        3)
            log_warning "Using password authentication"
            SSH_KEY_PATH=""
            ;;
        4)
            log_info "Exiting"
            exit 0
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
    
    return 0
}

# === Validation functions ===
validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check if flake.nix exists
    if [[ ! -f "flake.nix" ]]; then
        log_error "flake.nix not found in current directory"
        exit 1
    fi

    # Check for GitHub PAT file
    if ! check_github_pat; then
        exit 1
    fi

    # Detect SSH configuration
    if ! detect_ssh_config "$TARGET_HOST"; then
        log_info "No SSH config entry found for '$TARGET_HOST'"
        
        # Try to detect SSH key
        if ! detect_ssh_key; then
            log_info "No SSH key found"
            setup_manual_ssh || exit 1
        fi
    fi

    # Final validation of SSH key (if we're using one)
    if [[ -n "$SSH_KEY_PATH" && ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH key not found at $SSH_KEY_PATH"
        exit 1
    fi

    # Check if nixos-anywhere is available
    if ! command -v nixos-anywhere &> /dev/null; then
        log_warning "nixos-anywhere not found, installing..."
        if command -v nix &> /dev/null; then
            nix profile install github:nix-community/nixos-anywhere
        else
            log_error "nix command not found. Please install Nix first."
            exit 1
        fi
    fi

    log_success "Prerequisites validated"
}

# === SSH connectivity test ===
test_ssh_connection() {
    log_info "Testing SSH connection to $TARGET_USER@$TARGET_HOST..."
    
    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    
    # Use SSH config if available, otherwise use key file or password auth
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        log_info "Using SSH config for host '$SSH_CONFIG_HOST'"
        if ssh "$SSH_CONFIG_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
            log_success "SSH connection established via SSH config"
            return 0
        fi
    else
        # Use key file if available
        if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
            ssh_opts="$ssh_opts -i $SSH_KEY_PATH"
        fi

        if ssh $ssh_opts "$TARGET_USER@$TARGET_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
            log_success "SSH connection established"
            return 0
        fi
    fi
    
    log_error "Cannot establish SSH connection to $TARGET_USER@$TARGET_HOST"
    log_info "Make sure:"
    log_info "  1. Target machine is powered on and accessible"
    log_info "  2. SSH daemon is running on target machine"
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        log_info "  3. SSH config for '$SSH_CONFIG_HOST' is correctly configured"
    else
        log_info "  3. SSH key is properly configured or password auth is available"
    fi
    log_info "  4. Network connectivity is available"
    return 1
}

# === Remote system preparation ===
prepare_remote_system() {
    log_info "Preparing remote system..."
    
    local ssh_cmd
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        ssh_cmd="ssh $SSH_CONFIG_HOST"
    else
        local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
            ssh_opts="$ssh_opts -i $SSH_KEY_PATH"
        fi
        ssh_cmd="ssh $ssh_opts $TARGET_USER@$TARGET_HOST"
    fi

    # Enable experimental features and ensure git is available
    $ssh_cmd bash -s "$TARGET_DISK" << 'EOF'
        TARGET_DISK="$1"
        
        # Enable experimental features
        mkdir -p /etc/nix
        echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

        # Install git if not available
        if ! command -v git &> /dev/null; then
            nix-env -iA nixos.git
        fi

        # Ensure the target disk exists
        if [[ ! -b "$TARGET_DISK" ]]; then
            echo "Warning: Target disk $TARGET_DISK not found"
            lsblk
        fi
EOF

    # Mount old home device if specified
    if [[ -n "$OLD_HOME_DEVICE" && "$COPY_HOME" == "true" ]]; then
        log_info "Mounting old btrfs disk: $OLD_HOME_DEVICE"
        
        $ssh_cmd bash -s "$OLD_HOME_DEVICE" "$OLD_HOME_BTRFS_MOUNT" << 'EOF'
            OLD_HOME_DEVICE="$1"
            OLD_HOME_BTRFS_MOUNT="$2"
            
            # Create mount point if it doesn't exist
            mkdir -p "$OLD_HOME_BTRFS_MOUNT"
            
            # Check if device exists
            if [[ ! -b "$OLD_HOME_DEVICE" ]]; then
                echo "Error: Device $OLD_HOME_DEVICE not found"
                lsblk
                exit 1
            fi
            
            # Check if already mounted
            if mountpoint -q "$OLD_HOME_BTRFS_MOUNT" 2>/dev/null; then
                echo "Device already mounted at $OLD_HOME_BTRFS_MOUNT"
            else
                # Mount the btrfs device with @home subvolume
                if mount -t btrfs "$OLD_HOME_DEVICE" "$OLD_HOME_BTRFS_MOUNT"; then
                    echo "Successfully mounted btrfs device $OLD_HOME_DEVICE to $OLD_HOME_BTRFS_MOUNT"
                else
                    echo "Failed to mount $OLD_HOME_DEVICE"
                    exit 1
                fi
            fi
            
            # Verify mount was successful
            if mountpoint -q "$OLD_HOME_BTRFS_MOUNT" 2>/dev/null; then
                echo "Mount verified successfully"
                # List available subvolumes
                echo "Available subvolumes:"
                btrfs subvolume list "$OLD_HOME_BTRFS_MOUNT" 2>/dev/null || true
            else
                echo "Error: Mount verification failed"
                exit 1
            fi
EOF
        
        if [[ $? -ne 0 ]]; then
            log_error "Failed to mount old btrfs disk"
            return 1
        fi
        
        log_success "Old btrfs disk mounted successfully"
    fi

    log_success "Remote system prepared"
}

# === Setup GitHub PAT on newly installed system ===
setup_secrets_post_install() {
    log_info "Setting up GitHub PAT and GPG key on newly installed system..."
    
    # Use the NEW NixOS credentials (after installation), not the live CD credentials
    local ssh_cmd
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        ssh_cmd="ssh $SSH_CONFIG_HOST"
    else
        local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
            ssh_opts="$ssh_opts -i $SSH_KEY_PATH"
        fi
        # Use NIXOS_USERNAME for the newly installed system
        ssh_cmd="ssh $ssh_opts $NIXOS_USERNAME@$TARGET_HOST"
    fi
    
    log_info "Connecting as: $NIXOS_USERNAME@$TARGET_HOST"
    
    # Create github-runner directory
    $ssh_cmd "sudo mkdir -p /var/lib/github-runner && sudo chmod 700 /var/lib/github-runner" || true
    
    # Create GitHub PAT file on the new system
    log_info "Creating GitHub PAT on newly installed system..."
    if $ssh_cmd "echo '$GITHUB_PAT' | sudo tee /var/lib/github-runner/token > /dev/null"; then
        log_success "GitHub PAT created on new system successfully"
    else
        log_error "Failed to create GitHub PAT on new system"
        return 1
    fi

    # Set proper permissions on remote secrets
    $ssh_cmd "sudo chmod 600 /var/lib/github-runner/token" || true

    log_success "GitHub PAT configured on newly installed system at /var/lib/github-runner/token"
    
    # Export GPG key for SOPS decryption on GitHub runners
    log_info "Exporting GPG key for GitHub runners (SOPS)..."
    
    GPG_KEY_NAME="DC_ENCODE"
    
    $ssh_cmd bash -s "$GPG_KEY_NAME" << 'EOF'
        GPG_KEY_NAME="$1"
        OUTPUT_FILE="/var/lib/github-runner/gpg-key.b64"
        
        # Export the GPG key by name
        if gpg --export-secret-key --armor "$GPG_KEY_NAME" | base64 -w0 > "$OUTPUT_FILE" 2>/dev/null; then
            sudo chmod 600 "$OUTPUT_FILE"
            sudo chown github-runner:github-runner "$OUTPUT_FILE" 2>/dev/null || true
            echo "✓ GPG key (DC_ENCODE) exported successfully"
        else
            echo "Warning: Could not export GPG key from host"
            exit 0  # Continue anyway, as key might not exist on this system
        fi
EOF
    
    log_success "GPG key (DC_ENCODE) setup completed"
}
copy_home_folder() {
    if [[ "$COPY_HOME" != "true" ]]; then
        log_info "Skipping home folder copy (not requested)"
        return 0
    fi
    
    log_info "Copying home folder from old btrfs @home subvolume..."
    
    # Use the NEW NixOS credentials (after installation), not the live CD credentials
    local ssh_cmd
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        ssh_cmd="ssh $SSH_CONFIG_HOST"
    else
        local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
            ssh_opts="$ssh_opts -i $SSH_KEY_PATH"
        fi
        # Use NIXOS_USERNAME instead of TARGET_USER (which is root on live ISO)
        ssh_cmd="ssh $ssh_opts $NIXOS_USERNAME@$TARGET_HOST"
    fi
    
    log_info "Connecting as: $NIXOS_USERNAME@$TARGET_HOST"
    
    # Execute remote commands to copy home
    $ssh_cmd << EOF
        set -euo pipefail
        
        OLD_HOME_BTRFS_MOUNT="/mnt/old_btrfs"
        OLD_HOME_SUBVOL="\$OLD_HOME_BTRFS_MOUNT/@home"
        
        # Check if old btrfs mount point exists
        if [[ ! -d "\$OLD_HOME_BTRFS_MOUNT" ]]; then
            echo "Error: Mount point \$OLD_HOME_BTRFS_MOUNT does not exist"
            exit 1
        fi
        
        # Check if @home subvolume is mounted
        if [[ ! -d "\$OLD_HOME_SUBVOL" ]]; then
            echo "Error: @home subvolume not found at \$OLD_HOME_SUBVOL"
            ls -la "\$OLD_HOME_BTRFS_MOUNT"
            exit 1
        fi
        
        echo "Copying contents from \$OLD_HOME_SUBVOL to /home..."
        
        # Copy files while preserving ownership and permissions
        # First ensure /home exists and has correct permissions
        mkdir -p /home
        chmod 755 /home
        
        # Copy with rsync if available, otherwise use cp
        if command -v rsync &>/dev/null; then
            rsync -av --chown=root:root "\$OLD_HOME_SUBVOL/" /home/
        else
            cp -rp "\$OLD_HOME_SUBVOL/"* /home/ 2>/dev/null || true
        fi
        
        if [[ \$? -eq 0 ]]; then
            echo "Successfully copied home folder contents"
        else
            echo "Warning: Some files may not have been copied"
        fi
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "Home folder copied successfully"
        return 0
    else
        log_error "Failed to copy home folder"
        return 1
    fi
}

# === Main installation function ===
install_nixos() {
    log_info "Starting nixos-anywhere installation..."
    log_info "Target: $TARGET_USER@$TARGET_HOST"
    log_info "Disk: $TARGET_DISK"
    log_info "Flake: .#$FLAKE_CONFIG"

    # Build nixos-anywhere command
    local nixos_anywhere_cmd="nixos-anywhere"
    
    # Configure SSH options based on available authentication method
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        log_info "Using SSH config host: $SSH_CONFIG_HOST"
        nixos_anywhere_cmd="$nixos_anywhere_cmd --target-host $SSH_CONFIG_HOST"
    else
        # Add SSH options for direct connection
        nixos_anywhere_cmd="$nixos_anywhere_cmd --ssh-option StrictHostKeyChecking=no"
        nixos_anywhere_cmd="$nixos_anywhere_cmd --ssh-option UserKnownHostsFile=/dev/null"
        
        if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
            nixos_anywhere_cmd="$nixos_anywhere_cmd --ssh-option IdentityFile=$SSH_KEY_PATH"
        fi
        
        nixos_anywhere_cmd="$nixos_anywhere_cmd --target-host $TARGET_USER@$TARGET_HOST"
    fi

    # Add other options
    # Update disko.nix with the target disk
    log_info "Updating disko.nix with target disk: $TARGET_DISK"
    sed -i.bak "s|device = \"/dev/vda\"|device = \"$TARGET_DISK\"|g" disko.nix

    nixos_anywhere_cmd="$nixos_anywhere_cmd --flake .#$FLAKE_CONFIG"

    log_info "Executing: $nixos_anywhere_cmd"
    
    if eval "$nixos_anywhere_cmd"; then
        log_success "NixOS installation completed successfully!"
    else
        log_error "NixOS installation failed"
        return 1
    fi
}

# === Post-installation verification ===
verify_installation() {
    log_info "Verifying installation..."
    
    # Wait for system to reboot and become available
    log_info "Waiting for system to reboot..."
    sleep 30
    
    local ssh_cmd
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        # For SSH config, we need to update the target user to the NixOS user
        # This assumes the SSH config will work with the new user
        ssh_cmd="ssh ${SSH_CONFIG_HOST/_$TARGET_USER/_$NIXOS_USERNAME}"
        # If the host alias doesn't contain the user, try with the nixos user directly
        if [[ "$ssh_cmd" == "ssh $SSH_CONFIG_HOST" ]]; then
            ssh_cmd="ssh $NIXOS_USERNAME@$TARGET_HOST"
        fi
    else
        local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
            ssh_opts="$ssh_opts -i $SSH_KEY_PATH"
        fi
        ssh_cmd="ssh $ssh_opts $NIXOS_USERNAME@$TARGET_HOST"
    fi

    # Try to connect as the configured user
    local max_attempts=12
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Connection attempt $attempt/$max_attempts..."
        
        if $ssh_cmd "echo 'Post-installation SSH connection successful'" 2>/dev/null; then
            log_success "Post-installation verification successful!"
            if [[ "$USE_SSH_CONFIG" == "true" ]]; then
                log_info "You can now connect to your NixOS system using your SSH config"
            else
                log_info "You can now connect to your NixOS system using:"
                log_info "  ssh $NIXOS_USERNAME@$TARGET_HOST"
            fi
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    log_warning "Could not verify post-installation SSH connection"
    log_info "The installation may have completed successfully, but the system might still be booting"
    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        log_info "Try connecting manually in a few minutes using your SSH config"
    else
        log_info "Try connecting manually in a few minutes: ssh $NIXOS_USERNAME@$TARGET_HOST"
    fi
}

# === Cleanup function ===
cleanup() {
    log_info "Cleaning up temporary files..."
    # Restore disko.nix backup if it was modified
    if [[ -f "disko.nix.bak" ]]; then
        mv disko.nix.bak disko.nix
    fi
    
    # Unmount old home device if it was mounted
    if [[ -n "$OLD_HOME_DEVICE" && "$COPY_HOME" == "true" ]]; then
        log_info "Unmounting old btrfs disk"
        
        # Construct SSH command based on authentication method
        local ssh_cmd
        if [[ "$USE_SSH_CONFIG" == "true" ]]; then
            ssh_cmd="ssh $SSH_CONFIG_HOST"
        else
            local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
                ssh_opts="$ssh_opts -i $SSH_KEY_PATH"
            fi
            ssh_cmd="ssh $ssh_opts $NIXOS_USERNAME@$TARGET_HOST"
        fi
        
        $ssh_cmd bash -s << 'EOF'
            OLD_HOME_BTRFS_MOUNT="/mnt/old_btrfs"
            
            # Check if mount point is actually mounted
            if mountpoint -q "$OLD_HOME_BTRFS_MOUNT" 2>/dev/null; then
                if umount "$OLD_HOME_BTRFS_MOUNT"; then
                    echo "Successfully unmounted $OLD_HOME_BTRFS_MOUNT"
                else
                    echo "Warning: Failed to unmount $OLD_HOME_BTRFS_MOUNT (may be in use)"
                fi
            else
                echo "Mount point $OLD_HOME_BTRFS_MOUNT is not mounted"
            fi
EOF
    fi
}

# === Main execution ===
main() {
    log_info "Starting remote NixOS installation with SSH setup"
    log_info "================================================"

    parse_args "$@"
    
    # Prompt for any missing configuration
    prompt_for_configuration
    
    # Display configuration
    cat << EOF

Configuration:
  Target Host:     $TARGET_HOST
  Target User:     $TARGET_USER
  Target Disk:     $TARGET_DISK
  Flake Config:    $FLAKE_CONFIG
  NixOS User:      $NIXOS_USERNAME
  GitHub PAT:      <hidden>
  Copy Home:       $COPY_HOME
  Old Home Device: ${OLD_HOME_DEVICE:-N/A}

Authentication:
EOF

    if [[ "$USE_SSH_CONFIG" == "true" ]]; then
        echo "  Method:          SSH Config"
        echo "  SSH Host:        $SSH_CONFIG_HOST"
    elif [[ -n "$SSH_KEY_PATH" ]]; then
        echo "  Method:          SSH Key"
        echo "  SSH Key:         $SSH_KEY_PATH"
    else
        echo "  Method:          Password Authentication"
    fi

    echo

    read -p "Continue with installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    # Execute installation steps
    validate_prerequisites
    test_ssh_connection || exit 1
    prepare_remote_system
    install_nixos || exit 1
    verify_installation
    setup_secrets_post_install || exit 1
    copy_home_folder || exit 1
    cleanup

    log_success "Remote NixOS installation completed!"
    log_info "Your NixOS system is now ready with SSH access enabled"
    log_info "GitHub PAT has been saved to: /var/lib/github-runner/token"
    log_info "GPG key has been saved to: /var/lib/github-runner/gpg-key.b64"
    log_info ""
    log_info "GitHub runners will automatically use the GPG key from /var/lib/github-runner/gpg-key.b64"
    log_info "No GitHub Secrets needed!"
}

# === Signal handlers ===
trap cleanup EXIT
trap 'log_error "Installation interrupted"; exit 130' INT TERM

# Execute main function with all arguments
main "$@"
