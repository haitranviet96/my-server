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
    nixfmt
    btop-cuda
    gnupg
    sops
    age
    pciutils # for lspci command
    lsof
    mc
    python3
    bash
    btrbk
    tmux
    rclone
    google-cloud-sdk # AI
    claude-code # AI
    gemini-cli
    virt-manager # virt-install
    smartmontools
    # cloudflared
    caddy
    dig
    nmap
    unzip
    s-tui # power management
    powertop # power management
    linuxPackages.turbostat # power management
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    amdgpu_top
    nvtopPackages.full
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
