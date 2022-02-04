#!/bin/bash

sudo pacman -S - < pkglist.txt

flatpak install com.github.Eloston.UngoogledChromium
#flatpak install org.signal.Signal
#flatpak install org.videolan.VLC

# unbound
sudo curl --output /etc/unbound/root.hints https://www.internic.net/domain/named.cache


echo 'name_servers="::1 127.0.0.1"
resolv_conf_options="trust-ad"' | sudo tee /etc/resolvconf.conf

sudo resolvconf -u
