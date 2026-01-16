#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"
exec > >(tee -a $LOGFILE) 2>&1

# ------------------------------------------------------------
# 1. Disk Seçimi (liste)
# ------------------------------------------------------------
DISK=$(whiptail --title "Disk Seçimi" --menu "Kurulum yapılacak diski seçin:" 20 70 10 \
$(lsblk -d -n -o NAME,SIZE | awk '{print $1 " " $2}') \
3>&1 1>&2 2>&3)

if [ -z "$DISK" ]; then
  whiptail --title "Hata" --msgbox "Disk seçilmedi, kurulum iptal edildi." 10 60
  exit 1
fi

parted --script /dev/$DISK mklabel gpt
parted --script /dev/$DISK mkpart ESP fat32 1MiB 513MiB
parted --script /dev/$DISK set 1 boot on
parted --script /dev/$DISK mkpart primary ext4 513MiB 90%
parted --script /dev/$DISK mkpart primary linux-swap 90% 100%

mkfs.fat -F32 /dev/${DISK}1
mkfs.ext4 /dev/${DISK}2
mkswap /dev/${DISK}3
swapon /dev/${DISK}3

mount /dev/${DISK}2 /mnt
mkdir -p /mnt/boot
mount /dev/${DISK}1 /mnt/boot

# ------------------------------------------------------------
# 2. Ağ Ayarları
# ------------------------------------------------------------
NETTYPE=$(whiptail --title "Ağ Bağlantısı" --menu "Bağlantı türünü seçin:" 15 60 5 \
"wifi" "Kablosuz (Wi-Fi)" \
"ethernet" "Kablolu (Ethernet)" \
3>&1 1>&2 2>&3)

if [ "$NETTYPE" = "wifi" ]; then
  SSID=$(whiptail --title "Wi-Fi SSID" --inputbox "Wi-Fi ağ adını girin:" 10 60 3>&1 1>&2 2>&3)
  WIFIPASS=$(whiptail --title "Wi-Fi Şifresi" --passwordbox "$SSID için şifre:" 10 60 3>&1 1>&2 2>&3)
  pacman -Sy --noconfirm networkmanager
  systemctl enable NetworkManager
  systemctl start NetworkManager
  nmcli dev wifi connect "$SSID" password "$WIFIPASS"
else
  ETHDEV=$(ip link | awk -F: '/state UP|state DOWN/ && $2 ~ /en/ {print $2; exit}' | tr -d ' ')
  pacman -Sy --noconfirm networkmanager
  systemctl enable NetworkManager
  systemctl start NetworkManager
  nmcli dev set "$ETHDEV" managed yes
  nmcli con add type ethernet ifname "$ETHDEV" con-name "wired" autoconnect yes
fi

# ------------------------------------------------------------
# 3. Kullanıcı
# ------------------------------------------------------------
USERNAME=$(whiptail --title "Kullanıcı Adı" --inputbox "Yeni kullanıcı adı:" 10 60 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --title "Kullanıcı Şifresi" --passwordbox "$USERNAME için şifre:" 10 60 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --title "Root Şifresi" --passwordbox "Root için şifre:" 10 60 3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 4. Dil, Zaman Dilimi, Klavye
# ------------------------------------------------------------
LOCALE=$(whiptail --title "Dil Seçimi" --menu "Dil seçin:" 20 70 10 \
$(grep -E "UTF-8" /etc/locale.gen | sed 's/#//g' | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)

TIMEZONE=$(whiptail --title "Zaman Dilimi" --menu "Zaman dilimi seçin:" 20 70 15 \
$(timedatectl list-timezones | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)

KEYMAP=$(whiptail --title "Klavye Düzeni" --menu "Klavye düzeni seçin:" 20 70 15 \
$(localectl list-keymaps | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 5. Masaüstü Ortamı
# ------------------------------------------------------------
DE=$(whiptail --title "Masaüstü Ortamı" --menu "Masaüstü ortamı seçin:" 20 70 12 \
"gnome" "GNOME" \
"kde" "KDE Plasma" \
"xfce4" "XFCE" \
"cinnamon" "Cinnamon" \
"mate" "MATE" \
"lxqt" "LXQt" \
"deepin" "Deepin" \
"sway" "Sway (Wayland)" \
3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 6. Temel Sistem Kurulumu
# ------------------------------------------------------------
pacstrap /mnt base linux linux-firmware vim networkmanager git base-devel

genfstab -U /mnt >> /mnt/etc/fstab

# ------------------------------------------------------------
# 7. Chroot Ortamı
# ------------------------------------------------------------
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Locale
sed -i "s/^#\($LOCALE UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Keymap
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# User
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Desktop Environment
case $DE in
  gnome) pacman -S --noconfirm gnome gdm; systemctl enable gdm ;;
  kde) pacman -S --noconfirm plasma kde-applications sddm; systemctl enable sddm ;;
  xfce4) pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  cinnamon) pacman -S --noconfirm cinnamon lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  mate) pacman -S --noconfirm mate mate-extra lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  lxqt) pacman -S --noconfirm lxqt openbox sddm; systemctl enable sddm ;;
  deepin) pacman -S --noconfirm deepin deepin-extra lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  sway) pacman -S --noconfirm sway ;;
esac

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# ------------------------------------------------------------
# 8. Son Mesaj ve Reboot
# ------------------------------------------------------------
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux başarıyla kuruldu." 10 60
clear
if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
