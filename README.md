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
+1M
ef02
n
[Enter]
[Enter]
+550M
ef00
n
[Enter]
[Enter]
[Enter]
8309
w
```
5. `cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/nvme0n1p3`
6. `cryptsetup open /dev/nvme0n1p3 cryptlvm`