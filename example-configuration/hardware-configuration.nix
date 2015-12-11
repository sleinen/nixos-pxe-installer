{ config, lib, pkgs, ... }:

{
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/dummy";
      fsType = "ext4";
    };
}
