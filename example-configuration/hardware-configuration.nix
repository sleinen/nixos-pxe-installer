{ config, lib, pkgs, ... }:

{
  # imports =
  #     [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  #         ];

  # boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" ];
  # boot.kernelModules = [ "kvm-intel" ];
  #  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/dummy";
      fsType = "ext4";
    };

  # fileSystems."/boot" =
  #   { device = "/dev/disk/by-uuid/dummy";
  #     fsType = "vfat";
  #   };

  # swapDevices = [ ];

  # nix.maxJobs = 8;
}
