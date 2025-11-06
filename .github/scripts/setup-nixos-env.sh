#!/usr/bin/env bash

# NixOS GitHub Actions Environment Setup Script
# This script ensures all necessary tools are available in PATH for GitHub Actions runners

set -euo pipefail

# Set up proper PATH for NixOS system tools
export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"

# Verify essential tools are available
check_tool() {
    local tool=$1
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ Required tool '$tool' not found in PATH"
        echo "Current PATH: $PATH"
        exit 1
    fi
}

echo "🔧 Setting up NixOS GitHub Actions environment..."

# Check for essential tools
check_tool "sudo"
check_tool "nixos-rebuild"
check_tool "nix"
check_tool "systemctl"
check_tool "git"
check_tool "awk"

echo "✅ All required tools are available"

# Export the PATH for subsequent commands
echo "PATH=$PATH" >>"$GITHUB_ENV"

# Also create convenience aliases
echo "alias nixos-rebuild='sudo /run/current-system/sw/bin/nixos-rebuild'" >>"$GITHUB_ENV"
echo "alias nix='/run/current-system/sw/bin/nix'" >>"$GITHUB_ENV"
echo "alias systemctl='/run/current-system/sw/bin/systemctl'" >>"$GITHUB_ENV"
echo "alias journalctl='/run/current-system/sw/bin/journalctl'" >>"$GITHUB_ENV"

echo "🎯 Environment setup completed successfully"
