# Virtualization configuration: Docker, libvirtd
{ config, pkgs, lib, ... }:
{
  # Docker
  virtualisation.docker.enable = true;

  # Docker networks setup
  systemd.services.docker-networks = {
    description = "Create Docker networks";
    wantedBy = [ "docker.service" ];
    after = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ''
        ${pkgs.docker}/bin/docker network create --driver bridge --ipv6 multimedia || true
        ${pkgs.docker}/bin/docker network create --driver bridge --ipv6 webserver || true
        ${pkgs.docker}/bin/docker network create --driver bridge --ipv6 tools || true
      '';
    };
  };

  # Docker autostart - start all containers at boot
  systemd.services.docker-autostart = {
    description = "Start all Docker containers at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker start $(${pkgs.docker}/bin/docker ps -aq) || true'";
    };
  };

  # Docker autostop - stop all containers on shutdown/reboot
  systemd.services.docker-autostop = {
    description = "Stop all Docker containers on shutdown or reboot";
    wantedBy = [
      "halt.target"
      "reboot.target"
      "shutdown.target"
    ];
    before = [
      "shutdown.target"
      "reboot.target"
      "halt.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker stop $(${pkgs.docker}/bin/docker ps -q) || true'";
    };
  };

  # Enable virtualization stack (KVM/QEMU)
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
}
