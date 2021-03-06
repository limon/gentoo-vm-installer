#!/bin/bash
ifname=$(ls /sys/class/net/ | grep "enp\|eth")

#cat << EOF > /etc/systemd/network/$ifname.network
#[Match]
#Name=$ifname
#
#[Network]
#Address=192.168.1.181/24
#Gateway=192.168.1.100
#EOF
#echo 'nameserver 192.168.1.100' > /etc/resolv.conf

cat << EOF > /etc/systemd/network/$ifname.network
[Match]
Name=$ifname

[Network]
DHCP=ipv4
EOF

systemctl restart systemd-networkd
systemctl enable systemd-networkd

#sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 
#systemctl restart sshd
#systemctl enable sshd
