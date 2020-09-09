# Gentoo install script for Virtual Machines

Minimal Gentoo VM install script based on systemd profile

## Usage
1. Edit parameters (destination partition, mirror server, sync server, etc.) in start.sh
2. If you have customized make.conf, place it alongside the scripts
3. Partition disk by hand and run start.sh or just `./start.sh --autopart`
4. Set password
5. Reboot to new system
6. Edit and run config.sh for postinstall settings (network, sshd etc.)
