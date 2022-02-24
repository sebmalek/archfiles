#!/bin/bash

pacman -S - < pkglist.txt

#usermod -a -G wheel malek

systemctl enable gdm.service
systemctl enable NetworkManager.service

# unbound
sudo curl --output /etc/unbound/root.hints https://www.internic.net/domain/named.cache

# auto update root hints
sudo cp roothints.service /etc/systemd/system/roothints.service
sudo cp roothints.timer /etc/systemd/system/roothints.timer
sudo systemctl daemon-reload
sudo systemctl enable --now roothints.timer

sudo cp resolvconf.conf /etc/resolvconf.conf
sudo resolvconf -u

sudo cp unbound.conf /etc/unbound/unbound.conf
sudo systemctl restart unbound.service
