#!/bin/bash
echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
echo " ARCH LINUX GNOME LOADER "
echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
pacman -Sy
pacman -S --noconfirm lsblk
lsblk
echo "FIRST CAPTION: PREPARE DISK"
echo "NOW MAKE PARTITION DISKS [/]"
echo "WRITE DISK NAME [example /dev/nvme0n1]"
read CURRENTDISK

# Partitioning
parted $CURRENTDISK mklabel gpt
parted $CURRENTDISK mkpart ESP fat32 1MiB 512MiB
parted $CURRENTDISK set 1 boot on
parted $CURRENTDISK mkpart primary 512MiB 100%

# Partition variables (NVMe disklerde p1, p2 olur; SATA disklerde sda1, sda2)
BOOTPART=$(ls ${CURRENTDISK}* | grep -E "${CURRENTDISK}p?1$")
ROOTPART=$(ls ${CURRENTDISK}* | grep -E "${CURRENTDISK}p?2$")

echo "Boot Partition: $BOOTPART"
echo "Root Partition: $ROOTPART"

# Filesystems
mkfs.fat -F32 $BOOTPART
mkfs.ext4 $ROOTPART

# Mounting
mount $ROOTPART /mnt
mkdir /mnt/boot
mount $BOOTPART /mnt/boot

# Base system
pacstrap /mnt base linux linux-firmware networkmanager nano
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt <<EOF

# Bootloader
pacman -S --noconfirm unzip systemd
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
options root=$ROOTPART rw quiet splash
EOL

# GNOME + Plymouth
pacman -S --noconfirm gnome gdm plymouth git
systemctl enable gdm
systemctl enable NetworkManager
# Kullanıcı oluşturma
echo "ENTER NEW USER NAME [EXAMPLE FARI]"
read NEWUSER
useradd -m -G wheel -s /bin/bash $NEWUSER
passwd $NEWUSER

echo "CHOOSE NEW PASSWORD"
passwd
pacman -S --noconfirm sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Prepare GNOME and Plymouth Theme
pacman -S --noconfirm gnome gdm plymouth git
systemctl enable gdm
systemctl enable NetworkManager
git clone https://github.com/erenDO12/ARCHGNOMELOAD.git
cd ARCHGNOMELOAD
unzip GNOMEBOOT.zip
cp -r GNOMEBOOT /usr/share/plymouth/themes/
plymouth-set-default-theme -R gnomeboot
cd ..
rm -rf ARCHGNOMELOAD
mkinitcpio -P
pacman -R --noconfirm git
EOF

# Cleanup
umount -R /mnt
echo "FINISH LOAD GNOME OS VIA ARCH LINUX"
sleep 4
exit
