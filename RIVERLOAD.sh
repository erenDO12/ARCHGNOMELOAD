#!/bin/bash

TITLE="Arch River Installer"

# Disk seçimi
DISK=$(lsblk -dpno NAME | grep -E "/dev/sd|/dev/nvme" | \
  dialog --stdout --menu "Hedef Disk Seçin:" 20 60 10)

# Kullanıcı bilgileri
NEWUSER=$(dialog --stdout --inputbox "Yeni kullanıcı adı:" 10 50)
USERPASS=$(dialog --stdout --passwordbox "Kullanıcı şifresi:" 10 50)
ROOTPASS=$(dialog --stdout --passwordbox "Root şifresi:" 10 50)

# Özet ekranı
dialog --msgbox "Disk: $DISK\nKullanıcı: $NEWUSER" 10 50

# Partitioning
parted $DISK mklabel gpt
parted $DISK mkpart ESP fat32 1MiB 512MiB
parted $DISK set 1 boot on
parted $DISK mkpart primary 512MiB 100%

BOOTPART=$(ls ${DISK}* | grep -E "${DISK}p?1$")
ROOTPART=$(ls ${DISK}* | grep -E "${DISK}p?2$")

mkfs.fat -F32 $BOOTPART
mkfs.ext4 $ROOTPART

# Mount işlemleri artık /mnt altında
mount $ROOTPART /mnt
mkdir /mnt/boot
mount $BOOTPART /mnt/boot

# Base system
pacstrap /mnt base linux linux-firmware networkmanager nano sudo \
  river wlroots mesa intel-media-driver \
  alacritty waybar rofi greetd plymouth unzip git

genfstab -U /mnt >> /mnt/etc/fstab

# Chroot işlemleri
arch-chroot /mnt /bin/bash <<EOF
bootctl install
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen
echo 'arch-river' > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc

cat <<EOL > /boot/loader/loader.conf
default arch
timeout 3
console-mode keep
editor no
EOL

cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value $ROOTPART) rw quiet splash
EOL

systemctl enable NetworkManager
systemctl enable greetd
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

useradd -m -G wheel -s /bin/bash $NEWUSER
echo "$NEWUSER:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd

cat <<EOL > /etc/greetd/config.toml
[terminal]
vt = 1
[default_session]
command = "river"
user = "$NEWUSER"
EOL
EOF

umount -R /mnt
dialog --msgbox "Kurulum tamamlandı! Arch River hazır." 10 50
clear
