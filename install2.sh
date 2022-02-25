#!/bin/bash

# fail on error
set -eo pipefail

echo 'Setting timezone'
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc

echo 'Configuring pacman'
sed -i s/#ParallelDownloads/ParallelDownloads/g /etc/pacman.conf

echo 'Setting locale'
echo 'KEYMAP=croat' > /etc/vconsole.conf
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
sed -i '/#hr_HR.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo 'Settings hosts file'
echo -e '127.0.0.1\tlocalhost
::1\t\tlocalhost
127.0.1.1\tarch.localdomain\tarch' > /etc/hosts
echo 'arch' > /etc/hostname

echo 'Configuring sudo'
sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers
useradd -m -s /bin/zsh -G wheel -c 'Sebastian Malek' malek
passwd malek

# for chromium
echo 'kernel.unprivileged_userns_clone = 1' > /etc/sysctl.d/00-local-userns.conf

mkdir /root/secrets && chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin && chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 /dev/nvme0n1p3 /root/secrets/crypto_keyfile.bin

sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
sed -i "s|^FILES=.*|FILES=(/root/secrets/crypto_keyfile.bin)|g" /etc/mkinitcpio.conf
mkinitcpio -p linux-hardened

echo 'Configuring grub'
sed -i '/GRUB_ENABLE_CRYPTODISK/s/^#//g' /etc/default/grub
BLKID=$(blkid | grep nvme0n1p3 | cut -d '"' -f 2)
GRUBCMD="\"cryptdevice=UUID=$BLKID:cryptlvm root=/dev/vg/root cryptkey=rootfs:/root/secrets/crypto_keyfile.bin random.trust_cpu=on\""
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=${GRUBCMD}|g" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/efi
grub-mkconfig -o /boot/grub/grub.cfg

chmod 700 /boot

echo 'Installing packages'
pacman -S - < pkglist.txt

systemctl enable gdm.service

echo 'Configuring NetworkManager'
echo '[main]
dns=none' > /etc/NetworkManager/conf.d/dns.conf
systemctl enable NetworkManager.service

echo 'Configuring unbound'
mv /unbound.conf /etc/unbound/unbound.conf
systemctl enable unbound.service

echo 'Configuring resolvconf'
mv /resolvconf.conf /etc/resolvconf.conf
#resolvconf -u

echo 'Configuring ccache'
echo 'max_size = 20.0G
max_files = 0' >> /etc/ccache.conf

echo 'Configuring makepkg'
sed -i '/^BUILDENV/s/\!ccache/ccache/' /etc/makepkg.conf
sed -i '/#MAKEFLAGS=/c MAKEFLAGS="-j$(nproc)"' /etc/makepkg.conf
sed -i 's/^COMPRESSGZ.*/COMPRESSGZ=(pigz -c -f -n)/' /etc/makepkg.conf
sed -i '/^COMPRESSXZ/s/\xz/xz -T 0/' /etc/makepkg.conf