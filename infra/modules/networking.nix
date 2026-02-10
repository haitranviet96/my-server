# Networking configuration: SSH, Tailscale, firewall, network bridge
{ config, pkgs, lib, ... }:
{
  # SSH configuration - key-only authentication
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;
    };
  };

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
      5201 # iperf3
      61208 # glances HTTP
      19999 # netdata default port
    ];
    # Allow Tailscale traffic
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # Network bridge for VMs
  networking.useNetworkd = true;
  networking.bridges.br0.interfaces = [ "eno1" ];
  networking.interfaces.br0.useDHCP = true;
  networking.interfaces.eno1.useDHCP = false;
}
