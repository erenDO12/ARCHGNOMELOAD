#!/bin/bash
echo xxxxxxxxxxxxxxxxxxxxxxxx
echo ARCH LINUX GNOME LOADER
echo xxxxxxxxxxxxxxxxxxxxxxxx
echo FIRST CAPTION PREPARE DISK
echo NOW MAKE PARTITION DISKS [/]
echo WRITE DISK NAME [example /dev/sda]
read CURRENTDISK
parted $CURRENTDISK mklabel gpt
parted $CURRENTDISK mkpart ESP fat32 1MiB 512MiB
parted $CURRENTDISK set 1 boot on
parted $CURRENTDISK mkpart primary 512MiB 100%
mkfs.fat -F32 ${CURRENTDISK}1
mkfs.ext4 ${CURRENTDISK}2
mount ${disk}2 /mnt
mkdir /mnt/boot
mount ${disk}1 /mnt/boot
pacman -S systemd
echo THEN PACSTRAP LOAD SYSTEM ROOT [/]
pacstrap /mnt base linux linux-firmware networkmanager nano
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
# Kernel parametreleri
bootctl install
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "arch-gnome" > /etc/hostname
echo "default arch" > /boo/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo "#console-mode keep" >> /boot/loader/loader.conf
echo "editor no" >> /boot/loader/loader.conf
echo "title   Arch Linux" > /boot/loader/entries/arch.conf
echo "linux   /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "options root=${disk}2 rw" >> /boot/loader/entries/arch.conf
echo NOW GNOME OS LOAD DESKTOP [/]
pacman -S gnome gdm plymouth
systemctl enable gdm
systemctl enable NetworkManager
unzip GNOMEBOOT.zip
sudo plymouth-set-default-theme -R gnomeboot
mkinitpcio -P
umount -R /mnt
echo FINISH LOAD GNOME OS VIA ARCH LINUX
sleep 4
exit
