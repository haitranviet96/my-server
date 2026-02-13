# Programs and packages configuration
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # system packages
  environment.systemPackages = with pkgs; [
    inetutils
    vim
    curl
    wget
    dua
    tailscale
    nixfmt-rfc-style
    btop-cuda
    gnupg
    sops
    age
    pciutils # for lspci command
    mc
    python3
    bash
    btrbk
    tmux
    rclone
    stress-ng
    google-cloud-sdk # AI
    claude-code # AI
    virt-manager # virt-install
    smartmontools
    cloudflared
  ];

  # Enable nix-ld for FHS compatibility
  programs.nix-ld.enable = true;

  # Enable envfs for better environment compatibility
  services.envfs.enable = true;

  # iotop with kernel support
  programs.iotop.enable = true;

  # GPG configuration
  programs.gnupg.agent = {
    pinentryPackage = pkgs.pinentry-curses; # For headless server
  };

  # Git configuration
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Hai Tran";
        email = "haitranviet96@gmail.com";
      };
      credential.helper = "store";
    };
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };
}
