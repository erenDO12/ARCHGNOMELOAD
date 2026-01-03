#!/bin/bash
echo "====================================="
echo "   ARCH LINUX GNOME AUTO LOADER   "
echo "====================================="

# Sync package database
pacman -Sy --noconfirm
pacman -S --noconfirm lsblk parted

# Show disks
lsblk
echo " x PREPARE DISK "
echo "Enter target disk (example: /dev/nvme0n1):"
read CURRENTDISK

echo "Enter new username (example: fari):"
read NEWUSER

echo "Enter password for new user:"
read -s USERPASS

echo "Enter root password:"
read -s ROOTPASS

# Partitioning
parted $CURRENTDISK mklabel gpt
parted $CURRENTDISK mkpart ESP fat32 1MiB 512MiB
parted $CURRENTDISK set 1 boot on
parted $CURRENTDISK mkpart primary 512MiB 100%

# Partition variables (NVMe: p1/p2, SATA: sda1/sda2)
BOOTPART=$(ls ${CURRENTDISK}* | grep -E "${CURRENTDISK}p?1$")
ROOTPART=$(ls ${CURRENTDISK}* | grep -E "${CURRENTDISK}p?2$")

echo "Boot Partition: $BOOTPART"
echo "Root Partition: $ROOTPART"

# Filesystems
mkfs.fat -F32 $BOOTPART
mkfs.ext4 $ROOTPART

# Mounting
mkdir /made
mount $ROOTPART /made
mkdir /made/boot
mount $BOOTPART /made/boot

# Base system
pacstrap /made base linux linux-firmware networkmanager nano sudo gdm gnome plymouth unzip git
genfstab -U /made >> /made/etc/fstab

# Chroot configuration
arch-chroot /made /bin/bash -c "

# Bootloader
bootctl install

# Locale setup (ONLY English enabled)
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen

# Hostname
echo 'arch-gnome' > /etc/hostname

# Hosts configuration
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch-gnome.localdomain arch-gnome
EOL

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc

# Boot loader config
cat <<EOL > /boot/loader/loader.conf
default arch
timeout 3
console-mode keep
editor no
EOL

# Boot entry (UUID safer)
cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value $ROOTPART) rw quiet splash
EOL

# Enable services
systemctl enable gdm
systemctl enable NetworkManager

# Sudoers
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

# Create user and set passwords
useradd -m -G wheel -s /bin/bash $NEWUSER
echo \"$NEWUSER:$USERPASS\" | chpasswd
echo \"root:$ROOTPASS\" | chpasswd

# Plymouth theme setup
git clone https://github.com/erenDO12/ARCHGNOMELOAD.git
cd ARCHGNOMELOAD
unzip GNOMEBOOT.zip
mv GNOMEBOOT /usr/share/plymouth/themes/gnomeboot
plymouth-set-default-theme gnomeboot
mkinitcpio -P
cd ..
rm -rf ARCHGNOMELOAD
pacman -R --noconfirm git
"

# Cleanup
umount -R /made
echo "FINISH LOAD GNOME OS VIA ARCH LINUX"
sleep 4
exit
