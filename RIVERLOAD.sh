#!/bin/bash

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"

# ------------------------------------------------------------
# 1. Disk Seçimi ve Hazırlığı
# ------------------------------------------------------------
DISK=$(whiptail --title "Disk Seçimi" --menu "Kurulum yapılacak diski seçin:" 20 70 10 \
$(lsblk -d -n -o NAME,SIZE | awk '{print $1 " " $2}') \
3>&1 1>&2 2>&3)

parted /dev/$DISK mklabel gpt
parted /dev/$DISK mkpart ESP fat32 1MiB 513MiB
parted /dev/$DISK set 1 boot on
parted /dev/$DISK mkpart primary ext4 513MiB 90%
parted /dev/$DISK mkpart primary linux-swap 90% 100%

mkfs.fat -F32 /dev/${DISK}1
mkfs.ext4 /dev/${DISK}2
mkswap /dev/${DISK}3
swapon /dev/${DISK}3

mount /dev/${DISK}2 /mnt
mkdir /mnt/boot
mount /dev/${DISK}1 /mnt/boot

# ------------------------------------------------------------
# 2. Temel Sistem Kurulumu
# ------------------------------------------------------------
whiptail --title "Temel Sistem Kurulumu" --msgbox "Arch Linux temel paketleri kuruluyor..." 10 60
pacstrap /mnt base linux linux-firmware vim networkmanager

# ------------------------------------------------------------
# 3. fstab Oluşturma
# ------------------------------------------------------------
whiptail --title "fstab" --msgbox "Disk bölümleri fstab dosyasına yazılıyor..." 10 60
genfstab -U /mnt >> /mnt/etc/fstab

# ------------------------------------------------------------
# 4. Chroot Ortamı ve Sistem Ayarları
# ------------------------------------------------------------
arch-chroot /mnt /bin/bash <<EOF

# Dil Seçimi
LOCALE=$(whiptail --title "Dil Seçimi" --menu "Dil seçin:" 20 70 10 \
$(grep -E "UTF-8" /etc/locale.gen | sed 's/#//g' | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
sed -i "s/^#\($LOCALE UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Zaman Dilimi
TIMEZONE=$(whiptail --title "Zaman Dilimi" --menu "Zaman dilimi seçin:" 20 70 15 \
$(timedatectl list-timezones | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Klavye Düzeni
KEYMAP=$(whiptail --title "Klavye Düzeni" --menu "Klavye düzeni seçin:" 20 70 15 \
$(localectl list-keymaps | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Kullanıcı
USERNAME=$(whiptail --title "Kullanıcı Adı" --inputbox "Yeni kullanıcı adı:" 10 60 3>&1 1>&2 2>&3)
useradd -m -G wheel -s /bin/bash "$USERNAME"
USERPASS=$(whiptail --title "Kullanıcı Şifresi" --passwordbox "$USERNAME için şifre:" 10 60 3>&1 1>&2 2>&3)
echo "$USERNAME:$USERPASS" | chpasswd
ROOTPASS=$(whiptail --title "Root Şifresi" --passwordbox "Root için şifre:" 10 60 3>&1 1>&2 2>&3)
echo "root:$ROOTPASS" | chpasswd

# Masaüstü Ortamı
DE=$(whiptail --title "Masaüstü Ortamı" --menu "Masaüstü ortamı seçin:" 20 70 10 \
"gnome" "GNOME" \
"kde" "KDE Plasma" \
"xfce4" "XFCE" \
"cinnamon" "Cinnamon" \
"mate" "MATE" \
"lxqt" "LXQt" \
3>&1 1>&2 2>&3)

case $DE in
  gnome) pacman -S --noconfirm gnome gdm; systemctl enable gdm ;;
  kde) pacman -S --noconfirm plasma kde-applications sddm; systemctl enable sddm ;;
  xfce4) pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  cinnamon) pacman -S --noconfirm cinnamon lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  mate) pacman -S --noconfirm mate mate-extra lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  lxqt) pacman -S --noconfirm lxqt openbox sddm; systemctl enable sddm ;;
esac

# Bootloader
whiptail --title "Bootloader" --msgbox "GRUB kuruluyor..." 10 60
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# ------------------------------------------------------------
# 6. Kurulum Sonrası Mesaj ve Yeniden Başlatma
# ------------------------------------------------------------
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux başarıyla kuruldu." 10 60
clear
if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
