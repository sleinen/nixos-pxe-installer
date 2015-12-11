{ config, pkgs, lib, ... }:

with lib;

{
  imports = [ nixos/modules/installation-nfsroot.nix ];

  customInstaller = {
    ## This is a bit hacky, but how do you expand a relative path
    ## name to an absolute path name with a proper Nix expression?
    nixosConfigDir = maybeEnv "PWD" "/nosuchdir" + "/example-configuration";
    rootDevice = "/dev/sda";
    networking = {
      # Use DHCP for all interfaces
      useDHCP = true;

      # The following would disable DHCP and cause the installer to create
      # a static network configuration for the interface "enp12s0" (using the
      # "usePredictableInterfaceNames" feature) from the information
      # discovered via DHCP when the system is configured.
      ##useDHCP = false;
      ##staticInterfaceFromDHCP = "enp12s0";
    };
  };

  nfsroot.bootLoader = {
    # Set the interfaces used during PXE boot,
    # defaults to "efinet0" and "eth0", respectively
    ##efinetDHCPInterface = "efinet6";
    ##linuxPnPInterface = "eth6";
  };
}
