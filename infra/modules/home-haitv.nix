# Home Manager configuration for haitv user
{ config, pkgs, lib, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.haitv =
    {
      pkgs,
      config,
      ...
    }:
    {
      # Enable home-manager
      programs.home-manager.enable = true;

      # Home Manager state version
      home.stateVersion = "25.11";

      # Install Node.js and pnpm
      home.packages = with pkgs; [
        nodejs
        pnpm
      ];

      # Add Codex binary path to user session
      home.sessionPath = [ "$HOME/.local/bin" ];

      # Configure pnpm global directory
      home.sessionVariables = {
        PNPM_HOME = "$HOME/.local/share/pnpm";
      };

      # Auto-install OpenAI Codex CLI via pnpm
      home.activation.installCodex = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        if ! [ -f "$HOME/.local/bin/codex" ]; then
          echo "Installing Codex CLI via pnpm..."

          # Ensure directories exist
          mkdir -p "$HOME/.local/bin"
          mkdir -p "$HOME/.local/share/pnpm"

          # Set up pnpm config for global installations
          export PNPM_HOME="$HOME/.local/share/pnpm"
          export PATH="$HOME/.local/bin:${pkgs.nodejs}/bin:${pkgs.pnpm}/bin:$PNPM_HOME:$PATH"

          # Configure pnpm global bin directory
          ${pkgs.pnpm}/bin/pnpm config set global-bin-dir "$HOME/.local/bin"
          ${pkgs.pnpm}/bin/pnpm config set global-dir "$HOME/.local/share/pnpm"

          # Install Codex CLI globally
          ${pkgs.pnpm}/bin/pnpm add -g @openai/codex || echo "Failed to install Codex CLI"
        fi
      '';
    };
}
