# Users configuration: haitv, github-runner
{ config, pkgs, lib, ... }:
{
  # Main user
  users.users.haitv = {
    isNormalUser = true;
    hashedPassword = "$6$wV.gZ4G6JUE3gikF$OioZi5wbTtZeR31NDgwzqoKC1sAho5qJxttuUE82u/0EBiN9WoBedbMehGPt/kvkzd9lIuHKhgLd0022wBjOJ0";
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB2+OS6UOfiyAeJNyAvFvPLbVhcjeSTHni08+9O0vTjy nixos-vm"
    ];
    shell = pkgs.zsh;
  };

  # default shell for all newly created interactive users
  users.defaultUserShell = pkgs.zsh;

  # expose shells
  environment.shells = with pkgs; [
    zsh
    bash
  ];

  # GitHub runner user
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
    extraGroups = [ "docker" ];
  };
  users.groups.github-runner = { };

  # Ensure github-runner token is persisted
  systemd.tmpfiles.rules = [
    "f /var/lib/github-runner/token 0600 github-runner github-runner - "
  ];
}
