#!/bin/bash
source /etc/profile

emerge-webrsync
emerge --sync
eselect profile set default/linux/amd64/17.1/systemd

echo "Asia/Shanghai" > /etc/timezone
emerge --config sys-libs/timezone-data

cat << EOF > /etc/locale.gen
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
EOF
locale-gen

cat << EOF > /etc/env.d/02locale
LANG="en_US.UTF-8"
EOF

env-update

emerge sys-kernel/gentoo-kernel-bin grub linux-firmware

grub-install
grub-mkconfig -o /boot/grub/grub.cfg

echo "Set root password"
passwd

exit
