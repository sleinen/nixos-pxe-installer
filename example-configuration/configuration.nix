{ config, pkgs, lib, ... }:

with lib;

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./networking.nix
    ];

  networking.usePredictableInterfaceNames = true;

  # Activate serial console
  boot.kernelParams = [ "console=ttyS0,115200n8" ];

  # Use the gummiboot efi boot loader.
  boot.loader.gummiboot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Zurich";

  services.openssh.enable = true;

  # Make user management strictly declerative.  We need
  # to set the password for the root account to be able to
  # log in on the console.  This will be the only access
  # to the system unless additional accounts are created
  # here.
  users.mutableUsers = false;
  users.extraUsers.root.hashedPassword = "$6$cSUnFL6MbD34$BaS0NLN1KCddegCaTKDMCc1D21Pdge9gFz5tr65U0KgNOgtrEoAGuVnelaPIuEb7iC0FOWE7HUG6NV2b2yN8s/";
  system.stateVersion = "15.09";
}
