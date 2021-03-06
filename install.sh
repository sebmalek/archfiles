#!/bin/bash

# fail on error
set -eo pipefail

timedatectl set-ntp true

cryptsetup luksFormat --type luks1 -S 1 -s 512 -h sha512 -i 2500 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm

lvcreate -L 10G vg -n swap
lvcreate -L 50G vg -n root
lvcreate -l 100%FREE vg -n home

mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap

mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap

mkfs.fat -F32 /dev/nvme0n1p1
mkdir /mnt/efi
mount /dev/nvme0n1p1 /mnt/efi

sed -i s/#ParallelDownloads/ParallelDownloads/g /etc/pacman.conf
pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 nano grub efibootmgr intel-ucode wget zsh sudo

genfstab -U /mnt >> /mnt/etc/fstab

cp install2.sh /mnt/install2.sh
cp pkglist.txt /mnt/pkglist.txt
cp nftables.conf /mnt/nftables.conf
cp unbound.conf /mnt/unbound.conf
cp resolvconf.conf /mnt/resolvconf.conf
arch-chroot /mnt ./install2.sh

rm /mnt/pkglist.txt
rm /mnt/install2.sh

umount -R /mnt
reboot
