#!/bin/bash
################################################################################################################################

MOUNT_POINT=/mnt/gentoo
DISK=/dev/sda
EFI_PART="${DISK}1"
SWAP_PART="${DISK}2"
ROOT_PART="${DISK}3"
SYNC_URI="rsync://mirrors.bfsu.edu.cn/gentoo-portage"
MIRROR_SERVER="https://mirrors.bfsu.edu.cn/gentoo"
STAGE3_TARBALL="$MIRROR_SERVER/releases/amd64/autobuilds/$(curl -s $MIRROR_SERVER/releases/amd64/autobuilds/latest-stage3-amd64-systemd.txt | tail -n 1 | cut -f 1 -d ' ')"

################################################################################################################################

function auto_part {
	cat << EOF | sfdisk $DISK
label: gpt
unit: sectors
sector-size: 512

/dev/sda1 : start=        2048, size=      614400, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/sda2 : start=      616448, size=    16777216, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
/dev/sda3 : start=    17393664, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
	mkfs.vfat -F32 "$EFI_PART"
	mkswap "$SWAP_PART"
	mkfs.ext4 -F "$ROOT_PART"
}

function yes_or_terminate {
	printf "$1?(y\N): "
	read yn
	case $yn in
		[Yy]* ) ;;
		* ) exit;;
	esac
}

function terminate {
	echo $1
	exit
}

function list_params {
	echo "DISK=$DISK"
	echo "EFI_PART=$EFI_PART"
	echo "SWAP_PART=$SWAP_PART"
	echo "ROOT_PART=$ROOT_PART"
}

function check_partition_type {
	if ! blkid $EFI_PART | grep -q TYPE=\"vfat\"; then
		terminate "EFI partition wrong"
	fi

	if ! blkid $SWAP_PART | grep -q TYPE=\"swap\"; then
		terminate "Swap partition wrong"
	fi

	if ! blkid $ROOT_PART | grep -q TYPE=\"ext4\"; then
		terminate "Ext4 root partition wrong"
	fi
}

function gen_fstab {
	EFI_UUID=$(blkid $EFI_PART | grep -Po ' UUID="\K[0-9A-Za-z-]+')
	echo "UUID=$EFI_UUID     	/boot/efi 	vfat      	defaults,noatime 	0 2" > /tmp/fstab

	ROOT_UUID=$(blkid $ROOT_PART | grep -Po ' UUID="\K[0-9A-Za-z-]+')
	echo "UUID=$ROOT_UUID		/         	ext4     	defaults,noatime	0 1" >> /tmp/fstab

	SWAP_UUID=$(blkid $SWAP_PART | grep -Po ' UUID="\K[0-9A-Za-z-]+')
	echo "UUID=$SWAP_UUID		none		swap		sw			0 0" >> /tmp/fstab
}

function umount_all {
	umount $MOUNT_POINT/boot/efi
	umount -l $MOUNT_POINT/dev
	umount -l $MOUNT_POINT/sys
	umount -l $MOUNT_POINT/proc
	umount $MOUNT_POINT
}

if mount | grep -q $MOUNT_POINT
then
	yes_or_terminate "/mnt/gentoo already mounted, umount to continue"
	umount_all
fi

list_params

if [ "$1" = "--autopart" ]; then
	yes_or_terminate "$DISK WILL BE WIPED!!! ARE YOU SURE TO CONTINUE"
	auto_part
fi

check_partition_type
gen_fstab

echo "Installing..."
echo 

mkdir $MOUNT_POINT 2> /dev/null
mount $ROOT_PART $MOUNT_POINT
mkdir -p $MOUNT_POINT/boot/efi
mount $EFI_PART $MOUNT_POINT/boot/efi

pushd $MOUNT_POINT
wget $STAGE3_TARBALL
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
popd

if [ -f ${BASH_SOURCE%/*}/make.conf ]; then
	cp ${BASH_SOURCE%/*}/make.conf $MOUNT_POINT/etc/portage/make.conf
else
	cat <<EOF >> $MOUNT_POINT/etc/portage/make.conf
GENTOO_MIRRORS="$MIRROR_SERVER"
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"
GRUB_PLATFORMS="efi-64"
EOF
fi

mkdir -p $MOUNT_POINT/etc/portage/repos.conf
cp $MOUNT_POINT/usr/share/portage/config/repos.conf $MOUNT_POINT/etc/portage/repos.conf/gentoo.conf
#sed -i 's/sync-rsync-verify-metamanifest = yes/sync-rsync-verify-metamanifest = no/' $MOUNT_POINT/etc/portage/repos.conf/gentoo.conf
sed -i "s|sync-uri.*|sync-uri = $SYNC_URI|" $MOUNT_POINT/etc/portage/repos.conf/gentoo.conf

cp --dereference /etc/resolv.conf $MOUNT_POINT/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

cp ${BASH_SOURCE%/*}/setup.sh $MOUNT_POINT
cp /tmp/fstab $MOUNT_POINT/etc/fstab
cp ${BASH_SOURCE%/*}/config.sh $MOUNT_POINT/root

chroot /mnt/gentoo /bin/bash /setup.sh

echo "Install Complete"
echo "Reboot and run /root/config.sh for final configuration"
