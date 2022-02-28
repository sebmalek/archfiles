# archfiles

To install, do the following:

1. `localectl set-keymap croat`
2. `pacman -Sy git`
3. `git clone https://github.com/sebmalek/archfiles`
4. `gdisk /dev/nvme0n1`
```
o
n
[Enter]
0
+550M
ef00
n
[Enter]
[Enter]
[Enter]
8309
w
```

### unbound
```
curl --output /etc/unbound/root.hints https://www.internic.net/domain/named.cache
cp roothints.service /etc/systemd/system/roothints.service
cp roothints.timer /etc/systemd/system/roothints.timer
systemctl daemon-reload
systemctl enable --now roothints.timer
```
