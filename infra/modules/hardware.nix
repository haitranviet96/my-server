# Hardware configuration: NVIDIA, CUDA, graphics, boot, kernel
{ config, pkgs, lib, ... }:
{
  # Allow unfree packages (needed for NVIDIA drivers)
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
  };

  # NVIDIA drivers
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Modesetting is required for most recent NVIDIA GPUs
    modesetting.enable = true;

    # Enable the Nvidia settings menu accessible via `nvidia-settings`
    nvidiaSettings = false; # Set to false for headless server

    # Enable NVIDIA Power Management (for newer GPUs)
    powerManagement.enable = true;

    nvidiaPersistenced = true;

    # Use open source kernel module (recommended for RTX/GTX 16xx and newer)
    # Set to false if you have older GPUs or encounter issues
    open = true;
  };

  # Enable CUDA support
  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # GPU passthrough (single GPU) via VFIO: bind NVIDIA GPU early
  # Disable host NVIDIA/Nouveau drivers; bind GPU to vfio-pci in initrd
  # boot.blacklistedKernelModules = [
  #   "nouveau"
  #   "nvidia"
  #   "nvidia_drm"
  #   "nvidia_modeset"
  #   "nvidia_uvm"
  # ];
  # boot.initrd.kernelModules = [
  #   "vfio_pci"
  #   "vfio"
  #   "vfio_iommu_type1"
  # ];
  # Map PCI IDs of GPU + audio (RTX 2060 12GB: 10de:1f03, audio: 10de:10f9)
  # and keep firmware framebuffers from grabbing the device
  # Note: keep existing fb disabling params below
  # Host will not have NVIDIA acceleration once passed through

  # Console-only system (no GUI)
  services.xserver.enable = false;

  # UEFI Bootloader
  boot.loader.systemd-boot.enable = true;

  # Assemble Intel IMSM (fake RAID) via mdadm at boot. NixOS exposes this via boot.swraid.
  boot.swraid.enable = true;

  # Enable kernel config for iotop
  boot.kernelParams = [
    "delayacct"
    "nomodeset"
    "video=efifb:off"
    "video=vesafb:off"
    "nvidia_drm.modeset=0"
    "pcie_aspm=force"
    "pcie_port_pm=on"
    # IOMMU + VFIO early binding for single-GPU passthrough (Intel platform)
    # "intel_iommu=on"
    # "iommu=pt"
    # "vfio-pci.ids=10de:1f03,10de:10f9"
    # "vfio-pci.disable_vga=1"
    # "initcall_blacklist=sysfb_init"
  ];
}
