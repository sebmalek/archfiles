#!/bin/bash

# fail on error
set -e

localectl set-keymap --no-convert croat

pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm

lvcreate -L 12G vg -n swap
lvcreate -L 50G vg -n root
lvcreate -l 100%FREE vg -n home

mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap

mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap

mkfs.fat -F32 /dev/nvme0n1p2
mkdir /mnt/efi
mount /dev/nvme0n1p2 /mnt/efi

sed -i s/#ParallelDownloads/ParallelDownloads/g /etc/pacman.conf
pacstrap /mnt base linux-hardened linux-firmware mkinitcpio lvm2 nano grub efibootmgr intel-ucode wget zsh sudo

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

echo 'KEYMAP=croat' > /etc/vconsole.conf

ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc

sed -i s/#ParallelDownloads/ParallelDownloads/g /etc/pacman.conf

sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo -e '127.0.0.1\tlocalhost
::1\t\tlocalhost
127.0.1.1\tarch.localdomain\tarch' > /etc/hosts
echo 'arch' > /etc/hostname

useradd -m -s /bin/zsh -G wheel malek

# for chromium
echo 'kernel.unprivileged_userns_clone = 1' > /etc/sysctl.d/00-local-userns.conf

mkdir /root/secrets && chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin && chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 /dev/nvme0n1p3 /root/secrets/crypto_keyfile.bin

sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
sed -i "s|^FILES=.*|FILES=(/root/secrets/crypto_keyfile.bin)|g" /etc/mkinitcpio.conf
mkinitcpio -p linux-hardened

sed -i '/GRUB_ENABLE_CRYPTODISK/s/^#//g' /etc/default/grub
BLKID=$(blkid | grep nvme0n1p3 | cut -d '"' -f 2)
GRUBCMD="\"cryptdevice=UUID=$BLKID:cryptlvm root=/dev/vg/root cryptkey=rootfs:/root/secrets/crypto_keyfile.bin random.trust_cpu=on\""
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=${GRUBCMD}|g" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg

echo '[main]
dns=none' > /etc/NetworkManager/conf.d/dns.conf

chmod 700 /boot
