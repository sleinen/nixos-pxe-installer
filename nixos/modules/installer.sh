#! @shell@
set -e

# Set the PATH.
setPath() {
    local dirs="$1"
    export PATH=/empty
    for i in $dirs; do
        PATH=$PATH:$i/bin
        if test -e $i/sbin; then
            PATH=$PATH:$i/sbin
        fi
    done
}

setPath "@path@"

fail() {
    echo "Something went wrong, starting interactive shell..."
    exec setsid @shell@
}

trap 'fail' 0 ERR TERM INT

## At this point, the root fs is mounted r/w and contains
## /dev, /proc, /sys as well as a Nix store with all
## utilities needed to execute this script.
mkdir -m 0755 /dev/shm
mount -t tmpfs -o "rw,nosuid,nodev,size=50%" tmpfs /dev/shm
mkdir -m 0755 -p /dev/pts
mkdir -m 01777 -p /tmp
mkdir -m 0755 -p /var /var/log /var/lib /var/db
mkdir -m 0700 -p /root
chmod 0700 /root
#mkdir -m 0755 -p /bin # for the /bin/sh symlink

# Create a tmpfs on /run to hold runtime state for programs such as
# udev
mkdir -m 0755 -p /run
mount -t tmpfs -o "mode=0755,size=25%" tmpfs /run
mkdir -m 0755 -p /run/lock


# For backwards compatibility, symlink /var/run to /run, and /var/lock
# to /run/lock.
ln -s /run /var/run
ln -s /run/lock /var/lock

# Load the required kernel modules.
mkdir -p /lib
ln -s @modulesTree@/lib/modules /lib/modules
#echo @kmod@/bin/modprobe > /proc/sys/kernel/modprobe
for i in @kernelModules@; do
    echo "loading module $(basename $i)..."
    modprobe $i || true
done


# Create device nodes in /dev.
echo "running udev..."
mkdir -p /etc/udev
touch /etc/udev/hwdb.bin
ln -sfn @systemd@/lib/udev/rules.d /etc/udev/rules.d
@systemd@/lib/systemd/systemd-udevd --daemon
udevadm trigger --action=add
udevadm settle || true

export HOME=/root
cd ${HOME}

cat /proc/net/pnp | grep -v bootserver >/etc/resolv.conf

dev=@rootDevice@
echo "Installing NixOS on device $dev"

echo -n "Creating disk label..."
parted --align optimal --script $dev mklabel gpt
echo "done"

echo -n "Partitioning disk..."
parted --align optimal --script $dev mkpart primary fat32 0% 512MiB set 1 boot on
parted --align optimal --script $dev "mkpart primary ext4 512MiB -4GiB"
echo "done"

echo -n "Creating file systems..."
mkfs.vfat ${dev}1
mkfs.ext4 -q -F -L nixos ${dev}2
echo "done"

echo "Installing NixOS"
mkdir /mnt
mount ${dev}2 /mnt
mkdir /mnt/boot
mount ${dev}1 /mnt/boot

(cd /mnt && tar xzpf /nixos.tgz)
mkdir -m 0755 -p /mnt/run /mnt/home
mkdir -m 0755 -p /mnt/tmp/root
mkdir -m 0755 -p /mnt/var/setuid-wrappers

mount -o bind /proc /mnt/proc
mount -o bind /dev /mnt/dev
mount -o bind /sys /mnt/sys
mount -t efivarfs none /mnt/sys/firmware/efi/efivars
mount -t tmpfs -o "mode=0755" none /mnt/dev/shm
mount -t tmpfs -o "mode=0755" none /mnt/run
mount -t tmpfs -o "mode=0755" none /mnt/var/setuid-wrappers
rm -rf /mnt/var/run
ln -s /run /mnt/var/run

## Generate hardware-specific configuration
nixos-generate-config --root /mnt

for o in $(cat /proc/cmdline); do
    case $o in
        ip=*)
	    set -- $(IFS=:; for arg in $o; do if [ -n "$arg" ]; then echo $arg; else echo '""'; fi; done)
            interface=$6
            ;;
    esac
done

eval "$(dhcpcd -q -4 -G -p -c @dhcpcHook@ $interface)"
dnsServers_quoted=
for s in $dnsServers; do
    dnsServers_quoted="$dnsServers_quoted \"$s\""
done

if [ -n "@useDHCP@" -a "@useDHCP@" -eq 1 ]; then

    cat <<EOF >/mnt/etc/nixos/networking.nix
{ config, lib, pkgs, ... }:

{
  networking = {
    hostName = "$hostname";
    useDHCP = true;
  };
}
EOF
else
    cat <<EOF >/mnt/etc/nixos/networking.nix
{ config, lib, pkgs, ... }:

{
  networking = {
    hostName = "$hostname";
    interfaces.@staticInterfaceFromDHCP@.ip4 = [ {
      address = "$ipv4Address";
      prefixLength = $ipv4Plen;
    } ];
  
    useDHCP = false;
    defaultGateway = "$ipv4Gateway";
    nameservers = [ $dnsServers_quoted ];
  };
}
EOF

fi

## Make perl shut up
export LANG=
export LC_ALL=
export LC_TIME=

## NIX path to use in the chroot
export NIX_PATH=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/etc/nixos/configuration.nix

echo "generating system configuration"
NIX_REMOTE= NIX_SUBSTITUTERS= chroot /mnt @nix@/bin/nix-env -p /nix/var/nix/profiles/system -f '<nixpkgs/nixos>' --set -A system
echo "activating final configuration"
NIXOS_INSTALL_GRUB=1 chroot /mnt /nix/var/nix/profiles/system/bin/switch-to-configuration boot
chroot /mnt /nix/var/nix/profiles/system/activate
chmod 655 /mnt
umount /mnt/proc /mnt/dev/shm /mnt/dev /mnt/sys/firmware/efi/efivars /mnt/sys
umount /mnt/run /mnt/var/setuid-wrappers /mnt/boot /mnt

echo "rebooting into the new system"
reboot --force

## not reached
