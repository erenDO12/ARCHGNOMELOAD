#!/bin/bash

TITLE="Arch Enlightenment Installer"
LOGFILE="install.log"

# Başlangıç temizliği
umount -R /mnt 2>/dev/null
mkdir -p /mnt

# Gauge ile kurulum süreci
(
echo 5; echo "Disk seçimi yapılıyor..."
DISKS=$(lsblk -dpno NAME | grep -E "/dev/sd|/dev/nvme")
MENU_OPTS=()
for d in $DISKS; do
  MENU_OPTS+=("$d" "$d")
done
DISK=$(whiptail --title "$TITLE" --menu "Hedef Disk Seçin:" 20 60 10 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

NEWUSER=$(whiptail --title "$TITLE" --inputbox "Yeni kullanıcı adı:" 10 50 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --title "$TITLE" --passwordbox "Kullanıcı şifresi:" 10 50 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --title "$TITLE" --passwordbox "Root şifresi:" 10 50 3>&1 1>&2 2>&3)

echo 15; echo "Disk bölümlendirme..."
parted -s $DISK mklabel gpt >>$LOGFILE 2>&1
parted -s $DISK mkpart ESP fat32 1MiB 512MiB >>$LOGFILE 2>&1
parted -s $DISK set 1 boot on >>$LOGFILE 2>&1
parted -s $DISK mkpart primary 512MiB 100% >>$LOGFILE 2>&1

BOOTPART=$(ls ${DISK}* | grep -E "${DISK}p?1$")
ROOTPART=$(ls ${DISK}* | grep -E "${DISK}p?2$")

mkfs.fat -F32 $BOOTPART >>$LOGFILE 2>&1
mkfs.ext4 $ROOTPART >>$LOGFILE 2>&1

echo 25; echo "Disk mount ediliyor..."
mount $ROOTPART /mnt >>$LOGFILE 2>&1
mkdir -p /mnt/boot
mount $BOOTPART /mnt/boot >>$LOGFILE 2>&1

echo 40; echo "Mirror listesi güncelleniyor..."
pacman -Sy --noconfirm >>$LOGFILE 2>&1

echo 55; echo "Temel sistem kuruluyor..."
pacstrap /mnt base linux linux-firmware networkmanager nano sudo \
  enlightenment lightdm lightdm-gtk-greeter \
  vim git unzip plymouth systemd >>$LOGFILE 2>&1

echo 70; echo "fstab oluşturuluyor..."
genfstab -U /mnt >> /mnt/etc/fstab

echo 85; echo "Chroot işlemleri..."
arch-chroot /mnt <<EOF >>$LOGFILE 2>&1
bootctl install
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen
echo 'arch-enlightenment' > /etc/hostname
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
systemctl enable lightdm

echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

useradd -m -G wheel -s /bin/bash $NEWUSER
echo "$NEWUSER:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd
EOF

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Enlightenment hazır.\nLog: $LOGFILE" 10 60
clear
