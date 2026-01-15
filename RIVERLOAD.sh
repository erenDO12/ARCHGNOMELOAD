#!/bin/bash

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"

(
echo 10; echo "Dil seçimi yapılıyor..."

# 1. Dil / Locale
LOCALE=$(whiptail --title "Dil Seçimi" --menu "Kullanmak istediğiniz dili seçin:" 20 70 15 \
"en_US.UTF-8" "English (US)" \
"tr_TR.UTF-8" "Türkçe (Türkiye)" \
"de_DE.UTF-8" "Deutsch (Germany)" \
"fr_FR.UTF-8" "Français (France)" \
"es_ES.UTF-8" "Español (Spain)" \
3>&1 1>&2 2>&3)
sed -i "s/^#\($LOCALE\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo 30; echo "Bölge ve zaman dilimi seçiliyor..."

# 2. Bölge / Timezone
TIMEZONE=$(whiptail --title "Zaman Dilimi Seçimi" --menu "Kullanmak istediğiniz zaman dilimini seçin:" 20 70 15 $(timedatectl list-timezones | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo 50; echo "Klavye düzeni seçiliyor..."

# 3. Klavye Düzeni
KEYMAP=$(whiptail --title "Klavye Düzeni Seçimi" --menu "Kullanmak istediğiniz klavye düzenini seçin:" 20 70 15 $(localectl list-keymaps | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo 70; echo "Input method seçiliyor..."

# 4. Input Method
INPUT=$(whiptail --title "Input Method Seçimi" --menu "Kullanmak istediğiniz input method'u seçin:" 20 70 10 \
"none" "Yok" \
"ibus" "IBus" \
"fcitx" "Fcitx" \
"scim" "SCIM" \
3>&1 1>&2 2>&3)

if [ "$INPUT" = "ibus" ]; then
  cat >> /etc/environment <<EOF
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
EOF
elif [ "$INPUT" = "fcitx" ]; then
  cat >> /etc/environment <<EOF
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
fi

echo 85; echo "Wi-Fi ağları taranıyor..."

# 5. Ağ / Wi-Fi
SSID_LIST=$(nmcli -t -f SSID dev wifi | grep -v '^$' | awk '{print $1 " " $1}')
if [ -n "$SSID_LIST" ]; then
  WIFI=$(whiptail --title "Wi-Fi Seçimi" --menu "Bağlanmak istediğiniz Wi-Fi ağını seçin:" 20 70 15 $SSID_LIST 3>&1 1>&2 2>&3)
  WIFIPASS=$(whiptail --title "Wi-Fi Şifresi" --passwordbox "Seçilen Wi-Fi için şifre girin:" 10 60 3>&1 1>&2 2>&3)
  nmcli dev wifi connect "$WIFI" password "$WIFIPASS"
fi

echo 90; echo "Kullanıcı oluşturuluyor..."

# 6. Kullanıcı Adı ve Root Şifresi
USERNAME=$(whiptail --title "Kullanıcı Adı" --inputbox "Yeni kullanıcı adı girin:" 10 60 3>&1 1>&2 2>&3)
useradd -m -G wheel -s /bin/bash "$USERNAME"
USERPASS=$(whiptail --title "Kullanıcı Şifresi" --passwordbox "$USERNAME için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "$USERNAME:$USERPASS" | chpasswd
ROOTPASS=$(whiptail --title "Root Şifresi" --passwordbox "Root kullanıcısı için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "root:$ROOTPASS" | chpasswd

echo 95; echo "Masaüstü ortamı seçiliyor..."

# 7. Masaüstü Ortamı / WM Seçimi
DE=$(whiptail --title "Masaüstü Ortamı Seçimi" --menu "Kurmak istediğiniz masaüstü ortamını seçin:" 20 70 15 \
"gnome" "GNOME" \
"kde" "KDE Plasma" \
"xfce4" "XFCE" \
"cinnamon" "Cinnamon" \
"mate" "MATE" \
"lxqt" "LXQt" \
"deepin" "Deepin" \
"budgie" "Budgie" \
"hyperland" "Hyperland (Wayland WM)" \
"river" "River (Wayland WM - AUR)" \
"sway" "Sway (Wayland WM)" \
3>&1 1>&2 2>&3)

# Seçilen masaüstü ortamını kur
case $DE in
  gnome)
    pacman -S --noconfirm gnome gdm
    systemctl enable gdm
    ;;
  kde)
    pacman -S --noconfirm plasma kde-applications sddm
    systemctl enable sddm
    ;;
  xfce4)
    pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ;;
  cinnamon)
    pacman -S --noconfirm cinnamon lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ;;
  mate)
    pacman -S --noconfirm mate mate-extra lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ;;
  lxqt)
    pacman -S --noconfirm lxqt openbox sddm
    systemctl enable sddm
    ;;
  deepin)
    pacman -S --noconfirm deepin deepin-extra lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ;;
  budgie)
    pacman -S --noconfirm budgie-desktop lightdm lightdm-gtk-greeter
    systemctl enable lightdm
    ;;
  hyperland)
    pacman -S --noconfirm hyperland
    ;;
  river)
    # River AUR'da, yay ile kur
    sudo -u "$USERNAME" yay -S --noconfirm river
    ;;
  sway)
    pacman -S --noconfirm sway
    ;;
esac

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

# ------------------------------------------------------------
# 9. Kurulum Sonrası İşlemler
# ------------------------------------------------------------
umount -R /mnt || true
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux + $DE hazır.\nLog: $LOGFILE" 10 60
clear

if whiptail --yesno "Kurulum tamamlandı! Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
