#!/bin/bash

# fail on error
set -eo pipefail

echo 'Setting timezone'
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc

echo 'Configuring pacman'
sed -i s/#ParallelDownloads/ParallelDownloads/g /etc/pacman.conf

echo 'Setting locale'
#localectl set-x11-keymap hr
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
echo 'vm.swappiness = 10' > /etc/sysctl.d/10-tweaks.conf

echo 'Adding udev rules'
cat <<EOF > /etc/udev/rules.d/10-ledger.conf
# Nano S
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0001|1000|1001|1002|1003|1004|1005|1006|1007|1008|1009|100a|100b|100c|100d|100e|100f|1010|1011|1012|1013|1014|1015|1016|1017|1018|1019|101a|101b|101c|101d|101e|101f", TAG+="uaccess", TAG+="udev-acl"
# Nano X
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0004|4000|4001|4002|4003|4004|4005|4006|4007|4008|4009|400a|400b|400c|400d|400e|400f|4010|4011|4012|4013|4014|4015|4016|4017|4018|4019|401a|401b|401c|401d|401e|401f", TAG+="uaccess", TAG+="udev-acl"
EOF

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

grub-install --target=x86_64-efi --efi-directory=/efi --modules="luks2 part_gpt cryptodisk gcry_rijndael pbkdf2 gcry_sha512"
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
