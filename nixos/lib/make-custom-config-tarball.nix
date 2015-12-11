## This function creates a tarball that contains an almost complete NixOS
## system by copying the closure of the toplevel derivation of a particular
## NixOS configuration, whose store path is passed as the systemConfigPath
## argument.  The setup includes a copy of the NixOS channel to make
## "nixos-rebuild" work on the new system.
##
## The tarball is intended to be used by the fully-automated PXE-based
## installer, which will complete the installation by
##
##   generating the configuration that depends on the hardware of the
##   system
##
##   installing the system configuration into the systems profile
##   and switching to that profile
##
##   Activating the new configuration
##
{ pkgs
, lib

, # The NixOS configuration to be installed onto the disk image.
  config

, # The size of the disk, in MiB
  diskSize ? 2048

, # The amount of memort allocated to the VM, in MiB  
  memSize ? 1024

, # The absolute path to a directory that will be
  # copied to /etc/nixos on the system
  nixosConfigDir

, # The store path of the system configuration
  # created from the configuration in nixosConfigDir
  systemConfigPath

, # The name of the tarball to store in the derivation
  tarballName

, # Shell code executed after the VM has finished.
  postVM ? ""

}:

assert nixosConfigDir != null;
assert systemConfigPath != null;

with lib;

let
      sourcesChannel = import ../lib/make-channel.nix
        { inherit config pkgs; };
in

pkgs.vmTools.runInLinuxVM (
  pkgs.runCommand "nixos-custom-tarball"
    { preVM =
        ''
	  mkdir $out
          diskImage=nixos.img
          ${pkgs.vmTools.qemu}/bin/qemu-img create -f raw $diskImage "${toString diskSize}M"
          mv closure* xchg/
          cp -prd ${nixosConfigDir} xchg/
	'';
      buildInputs = [ pkgs.utillinux pkgs.perl pkgs.e2fsprogs ];
      exportReferencesGraph =
        map (x: [("closure-" + baseNameOf x) x])
          [ systemConfigPath
            sourcesChannel
            ## Build-time dependencies for activating
            ## the final NixOS configuration on the
            ## installed system.
            ## XXX Determine this reliably from pkgs
            pkgs.stdenv
            pkgs.busybox
            config.system.build.bootStage1
            pkgs.unzip
            pkgs.perlArchiveCpio
            pkgs.firmwareLinuxNonfree
          ];
      inherit postVM diskSize memSize;
      inherit nixosConfigDir;
    }
    ''
      rootDisk=/dev/vda

      # Create an empty filesystem and mount it.
      mkfs.ext4 -L nixos $rootDisk
      mkdir /mnt
      mount $rootDisk /mnt

      for dir in dev proc sys; do
        mkdir /mnt/$dir
        mount -o bind /$dir /mnt/$dir
      done

      mkdir /mnt/tmp
      mkdir /mnt/etc

      # Copy all paths in the closure to the filesystem.
      closures=/tmp/xchg/closure*
      storePaths=$(perl ${pkgs.pathsFromGraph} $closures)

      mkdir -p /mnt/nix/store
      echo "copying closures..."
      set -f
      cp -prd $storePaths /mnt/nix/store/
      set +f

      # Register the paths in the Nix database.
      printRegistration=1 perl ${pkgs.pathsFromGraph} $closures | \
          chroot /mnt ${config.nix.package}/bin/nix-store --load-db --option build-users-group ""

      # Add missing size/hash fields to the database. FIXME:
      # exportReferencesGraph should provide these directly.
      chroot /mnt ${config.nix.package}/bin/nix-store --verify --check-contents

      # `nixos-rebuild' requires an /etc/NIXOS.
      touch /mnt/etc/NIXOS

      # `switch-to-configuration' requires a /bin/sh
      mkdir -p /mnt/bin
      ln -s ${config.system.build.binsh}/bin/sh /mnt/bin/sh

      # Set up the initial NixOS channel
      echo "nixbld1:x:30001:30000:Nix build user 1:/var/empty:/run/current-system/sw/bin/nologin" >/mnt/etc/passwd
      echo "nixbld:x:30000:nixbld1" >/mnt/etc/group
      mkdir -p /mnt/nix/var/nix/profiles/per-user/root
      NIX_REMOTE= NIX_SUBSTITUTERS= chroot /mnt ${config.nix.package}/bin/nix-env \
               -p /nix/var/nix/profiles/per-user/root/channels \
               -i ${sourcesChannel}
      mkdir -m 0700 -p /mnt/root/.nix-defexpr
      ln -sfn /nix/var/nix/profiles/per-user/root/channels /mnt/root/.nix-defexpr/channels
      mkdir -m 0755 -p /mnt/var/lib/nixos

      # Copy the NixOS configuration from which the system configuration
      # was created.
      mkdir /mnt/etc/nixos
      (cd /tmp/xchg/$(basename ${nixosConfigDir}) && tar --exclude="*~" -cf - .) | (cd /mnt/etc/nixos && tar xf -)

      umount /mnt/proc /mnt/dev /mnt/sys
      echo "creating tarball from disk image"
      (cd /mnt && tar czf /tmp/xchg/${tarballName} .)
      umount /mnt
    ''
)
