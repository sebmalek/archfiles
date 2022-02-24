#!/bin/bash

pacman -S - < pkglist.txt

systemctl enable gdm.service
systemctl enable NetworkManager.service

# unbound
curl --output /etc/unbound/root.hints https://www.internic.net/domain/named.cache

# auto update root hints
cp roothints.service /etc/systemd/system/roothints.service
cp roothints.timer /etc/systemd/system/roothints.timer
systemctl daemon-reload
systemctl enable --now roothints.timer

cp resolvconf.conf /etc/resolvconf.conf
resolvconf -u

cp unbound.conf /etc/unbound/unbound.conf
systemctl restart unbound.service
