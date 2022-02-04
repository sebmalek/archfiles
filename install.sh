#!/bin/bash

sudo pacman -S - < pkglist.txt

flatpak install com.github.Eloston.UngoogledChromium
#flatpak install org.signal.Signal
#flatpak install org.videolan.VLC

# unbound
sudo curl --output /etc/unbound/root.hints https://www.internic.net/domain/named.cache

sudo cp resolvconf.conf /etc/resolvconf.conf
sudo resolvconf -u
