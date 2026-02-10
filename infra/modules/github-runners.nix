# GitHub Actions self-hosted runners
{ config, pkgs, lib, ... }:
{
  services.github-runners =
    let
      # Number of runners to create (easily configurable)
      runnerCount = 3;

      # Generate runners dynamically
      generateRunners =
        count:
        builtins.listToAttrs (
          map (
            i:
            let
              runnerName = "runner-${toString i}";
            in
            {
              name = runnerName;
              value = {
                enable = true;
                url = "https://github.com/haitranviet96/my-server";
                tokenFile = "/var/lib/github-runner/token";
                ephemeral = true;
                replace = true;
                name = "nixos-${runnerName}";

                extraLabels = [
                  "nixos"
                  "docker"
                  "self-hosted"
                  "ephemeral"
                  "instance-${toString i}"
                  "cuda"
                ];

                extraPackages = with pkgs; [
                  curl
                  docker
                  docker-compose
                  jq
                  nodejs_20
                  gcc
                  gnumake
                  gnupg
                  sops
                  rsync
                  openssh
                ];

                serviceOverrides = {
                  SupplementaryGroups = [ "docker" ];
                  Restart = pkgs.lib.mkForce "always";
                  RestartSec = "10s";

                  # Cleanup before each job
                  ExecStartPre = [
                    "${pkgs.docker}/bin/docker system prune -f --volumes"
                  ];

                  # Resource limits
                  MemoryMax = "6G";
                  CPUQuota = "300%";

                  # Security
                  NoNewPrivileges = true;
                  PrivateTmp = true;
                };
              };
            }
          ) (builtins.genList (i: i + 1) count)
        );
    in
    generateRunners runnerCount;
}
