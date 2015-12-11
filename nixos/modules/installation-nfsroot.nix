# This module creates the configuration for the target system and
# places it ina file system tree that can be exported as root file
# system during the installation process on the target.

{ config, lib, pkgs, ... }:

with lib;

let

  ## Create the system configuration from the custom NixOS
  ## configuration.  The closure of this derivation will be
  ## installed on the client.
  systemConfigPath = (import <nixpkgs/nixos/lib/eval-config.nix> {
    inherit (config.nixpkgs) system;
    modules = [ (config.customInstaller.nixosConfigDir + "/configuration.nix") ];
  }).config.system.build.toplevel;

  tarball = import ../lib/make-custom-config-tarball.nix rec {
    inherit pkgs lib config;
    inherit systemConfigPath;
    inherit (config.customInstaller) nixosConfigDir;
    tarballName = "nixos.tgz";

    postVM =
      ''
        mv xchg/${tarballName} $out
      '';
  };
  
in

{
  imports = [ ./nfsroot.nix ];

  options = {
    customInstaller = {
      nixosConfigDir = mkOption {
        default = null;
        example = "nixos-configuration";
        description = ''
          This option specifies the directory that holds the NixOS configuration
          that will be installed on the client.  It must contain the file
          <filename>configuration.nix</filename>, which must import the file
          <filename>./hardware-configuration.nix</filename> and should import
          <filename>./networking</filename>, if the automatic network configuration
          configuration provided by the useDHCP and staticInterfaceFromDHCP are
          used.

          The file <filename>hardware-configuration</filename> doesn't need to be
          present.  It will be created during the installation process, overwriting
          any existing file.
        '';
      };
      rootDevice = mkOption {
        default = "/dev/sda";
        example = "/dev/sda";
        description = ''
          This option specifies the disk to use for the installation.  The installer
          will use the entire disk for the NixOS system.  It creates two partitions,
          one of type VFAT to hold the EFI boot files of size 512MiB, the other of type
          EXT4 to hold the NixOS system.  The disk will be overwritten unconditionally.
        '';
      };
      networking = {
        useDHCP = mkOption {
          type = types.bool;
          default = true;
          description = ''
            If set to true, the installed system will use DHCP on all available
            interfaces.  If set to false, a static configuration is created according
            to the option staticInterfaceFromDHCP.
          '';
        };
        staticInterfaceFromDHCP = mkOption {
          default = null;
          example = "enp1s0";
          description = ''
            If useDHCP is false, a static interface configuration will be created
            for the interface specified in this option. The IP address, netmask and
            default gateway are taken from the DHCP information obtained during the
            installation process.
          '';
        };
      };
    };
  };
  
  config = { 

    ## XXX This assertion is not checked. Need to understand why.
    assertions = [
      { assertion =  customInstaller.networking.useDHCP == false ->
                     customInstaller.networking.staticInterfaceFromDHCP != null;
        message = "DHCP disabled but no static interface specified";
      }
    ];
    
    nfsroot = {
      contents = [
        { source = tarball + "/nixos.tgz";
          target = "/nixos.tgz";
        }
      ];
    };

    # Provide access to the tarball derivation
    system.build.customConfigTarball = tarball;
  };
}
