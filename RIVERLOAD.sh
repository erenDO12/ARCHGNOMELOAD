#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"
exec > >(tee -a $LOGFILE) 2>&1

# ------------------------------------------------------------
# 1. Disk Seçimi ve Bölümler
# ------------------------------------------------------------
DISK=$(lsblk -d -n -o NAME | awk '{print "/dev/"$1" /dev/"$1}' | \
whiptail --title "Disk Seçimi" --menu "Kurulum yapılacak diski seçin:" 20 70 10 \
3>&1 1>&2 2>&3)

if [[ $DISK == *"nvme"* ]]; then
  BOOTPART="${DISK}p1"
  ROOTPART="${DISK}p2"
else
  BOOTPART="${DISK}1"
  ROOTPART="${DISK}2"
fi

mkfs.fat -F32 $BOOTPART
mkfs.ext4 $ROOTPART

mount $ROOTPART /mnt
mkdir -p /mnt/boot
mount $BOOTPART /mnt/boot

# ------------------------------------------------------------
# 2. Ağ Ayarları
# ------------------------------------------------------------
pacman -Sy --noconfirm networkmanager dialog
systemctl enable NetworkManager

ETHDEV=$(ip link | awk -F: '/state UP|state DOWN/ && $2 ~ /en/ {print $2; exit}' | tr -d ' ')
NETNAME=$(whiptail --title "Ağ Bağlantısı" --inputbox "Bağlantı adı:" 10 60 "$ETHDEV" 3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 3. Kullanıcı Bilgileri
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
"river" "River (Wayland, AUR)" \
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
  river)
    pacman -S --noconfirm go rust git base-devel greetd
    cd /opt
    git clone https://aur.archlinux.org/yay.git
    chown -R $USERNAME:$USERNAME yay
    cd yay
    sudo -u $USERNAME makepkg -si --noconfirm
    sudo -u $USERNAME yay -S --noconfirm river
    # greetd ayarı
    echo "[greeter]\ncommand = river" > /etc/greetd/config.toml
    systemctl enable greetd
    ;;
esac

# Bootloader (systemd-boot)
bootctl install
echo "default arch.conf" > /boot/loader/loader.conf
cat <<CONF > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=$ROOTPART rw
CONF
EOF

# ------------------------------------------------------------
# 8. Son Mesaj ve Reboot
# ------------------------------------------------------------
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux başarıyla kuruldu." 10 60
clear
if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
