# Hardware configuration: NVIDIA, CUDA, graphics, boot, kernel
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # NVIDIA and AMD drivers
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.amdgpu = {
    initrd.enable = true;
    opencl.enable = true;
  };

  # For AMD iGPU
  hardware.enableRedistributableFirmware = true;

  # Console-only system (no GUI)
  services.xserver.enable = false;

  # UEFI Bootloader
  boot.loader.systemd-boot.enable = true;

  # Enable kernel config for iotop
  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersupersave"
  ];
}
