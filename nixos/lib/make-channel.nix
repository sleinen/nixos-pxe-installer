{ config, pkgs, ... }:

pkgs.runCommand "nixos-${config.system.nixosVersion}"
  { }
  ''
    mkdir -p $out
    cp -prd ${pkgs.path} $out/nixos
    chmod -R u+w $out/nixos
    [ -h $out/nixos/nixpkgs ] || ln -s . $out/nixos/nixpkgs
    rm -rf $out/nixos/.git
    echo -n ${config.system.nixosVersionSuffix} > $out/nixos/.version-suffix
  ''
