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

# for chromium
echo 'kernel.unprivileged_userns_clone = 1' > /etc/sysctl.d/00-local-userns.conf

echo 'vm.swappiness = 5' > /etc/sysctl.d/10-tweaks.conf

echo 'Adding udev rules'
cat <<EOF > /etc/udev/rules.d/20-hw1.rules
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0000|0000|0001|0002|0003|0004|0005|0006|0007|0008|0009|000a|000b|000c|000d|000e|000f|0010|0011|0012|0013|0014|0015|0016|0017|0018|0019|001a|001b|001c|001d|001e|001f", TAG+="uaccess", TAG+="udev-acl"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0004|4000|4001|4002|4003|4004|4005|4006|4007|4008|4009|400a|400b|400c|400d|400e|400f|4010|4011|4012|4013|4014|4015|4016|4017|4018|4019|401a|401b|401c|401d|401e|401f", TAG+="uaccess", TAG+="udev-acl"
EOF

mkdir /root/secrets && chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin && chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 /dev/nvme0n1p2 /root/secrets/crypto_keyfile.bin

echo 'blacklist mei
blacklist mei_wdt
blacklist iTCO_wdt' > /etc/modprobe.d/blacklist.conf

sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
sed -i "s|^FILES=.*|FILES=(/root/secrets/crypto_keyfile.bin)|g" /etc/mkinitcpio.conf
mkinitcpio -p linux

echo 'Configuring grub'
sed -i '/GRUB_ENABLE_CRYPTODISK/s/^#//g' /etc/default/grub
BLKID=$(blkid | grep nvme0n1p2 | cut -d '"' -f 2)
GRUBCMD="\"cryptdevice=UUID=$BLKID:cryptlvm:allow-discards root=/dev/vg/root cryptkey=rootfs:/root/secrets/crypto_keyfile.bin lsm=landlock,lockdown,yama,apparmor,bpf\""
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=${GRUBCMD}|g" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/efi --modules="luks2 part_gpt part_msdos cryptodisk gcry_rijndael pbkdf2 gcry_sha512"
grub-mkconfig -o /boot/grub/grub.cfg

chmod 700 /boot

echo 'Enabling TRIM'
systemctl enable fstrim.timer

echo 'Installing packages'
pacman -S - < pkglist.txt

useradd -m -s /bin/zsh -G wheel,wireshark -c 'Sebastian Malek' malek
passwd malek

echo 'Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "hr"
EndSection' > /etc/X11/xorg.conf.d/00-keyboard.conf

systemctl enable gdm.service

echo 'Configuring NetworkManager'
echo '[main]
dns=none' > /etc/NetworkManager/conf.d/dns.conf
systemctl enable NetworkManager.service

echo 'Configuring nftables'
mv /nftables.conf /etc/nftables.conf
systemctl enable nftables.service

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

echo 'Configuring NFS mounts'
mkdir /mnt/secrets
chmod 600 /mnt/secrets
chown malek:malek /mnt/secrets
echo -e '10.0.1.1:/secrets\t/mnt/secrets\tnfs\tvers=3,_netdev,noauto,x-systemd.automount,x-systemd.requires=wg-quick@wg0.service' >> /etc/fstab

echo 'Enabling AppArmor'
systemctl enable apparmor.service
