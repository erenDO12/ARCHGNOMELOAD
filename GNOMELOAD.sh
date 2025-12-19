#!/bin/bash
echo "=============================="
echo " ARCH LINUX GNOME LOADER "
echo "=============================="
echo "FIRST CAPTION: PREPARE DISK"
echo "NOW MAKE PARTITION DISKS [/]"
echo "WRITE DISK NAME [example /dev/sda]"
read CURRENTDISK

# Partitioning
parted $CURRENTDISK mklabel gpt
parted $CURRENTDISK mkpart ESP fat32 1MiB 512MiB
parted $CURRENTDISK set 1 boot on
parted $CURRENTDISK mkpart primary 512MiB 100%

# Filesystems
mkfs.fat -F32 ${CURRENTDISK}1
mkfs.ext4 ${CURRENTDISK}2

# Mounting
mount ${CURRENTDISK}2 /mnt
mkdir /mnt/boot
mount ${CURRENTDISK}1 /mnt/boot

# Base system
pacstrap /mnt base linux linux-firmware networkmanager nano
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt <<EOF

# Bootloader
bootctl install

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "arch-gnome" > /etc/hostname

# Boot loader config
echo "default arch" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo "console-mode keep" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf

# Boot entry
cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=${CURRENTDISK}2 rw
EOL

# GNOME + Plymouth
pacman -S --noconfirm gnome gdm plymouth
systemctl enable gdm
systemctl enable NetworkManager

unzip GNOMEBOOT.zip
cp -r gnomeboot /usr/share/plymouth/themes/
plymouth-set-default-theme -R gnomeboot

mkinitcpio -P
EOF

# Cleanup
umount -R /mnt
echo "FINISH LOAD GNOME OS VIA ARCH LINUX"
sleep 4
exit