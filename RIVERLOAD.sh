#!/bin/bash

TITLE="Arch River Installer"

# Disk seçimi
DISK=$(lsblk -dpno NAME | grep -E "/dev/sd|/dev/nvme" | \
  zenity --list --title="Disk Seçimi" --column="Diskler" --height=300 --width=400)

# Kullanıcı bilgileri
NEWUSER=$(zenity --entry --title="Yeni Kullanıcı" --text="Kullanıcı adı girin:")
USERPASS=$(zenity --password --title="Kullanıcı Şifresi")
ROOTPASS=$(zenity --password --title="Root Şifresi")

zenity --info --title="Özet" --text="Disk: $DISK\nKullanıcı: $NEWUSER"

# Partitioning
parted $DISK mklabel gpt
parted $DISK mkpart ESP fat32 1MiB 512MiB
parted $DISK set 1 boot on
parted $DISK mkpart primary 512MiB 100%

BOOTPART=$(ls ${DISK}* | grep -E "${DISK}p?1$")
ROOTPART=$(ls ${DISK}* | grep -E "${DISK}p?2$")

mkfs.fat -F32 $BOOTPART
mkfs.ext4 $ROOTPART

# Mount işlemleri
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
zenity --info --title="Kurulum Tamamlandı" --text="Arch River başarıyla kuruldu!"
