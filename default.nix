## This expression can be used to create all or part of the
## derivations of the installer system.  Executing nix-build in this
## directory creates all derivations.  Objects can be built selectively
## with the "-A" option of nix-build, e.g.
##
##  $ nix-build -A bootLoader
##
## will just create the boot loader.

{ system ? builtins.currentSystem }:

let

  eval = import <nixpkgs/nixos/lib/eval-config.nix> {
    inherit system;
    modules = [ ./create-installer.nix ];
  };

in

{
  inherit (eval.config.system.build.nfsroot) tarball bootLoader kernel;
  inherit (eval.config.system.build) customConfigTarball;
}
