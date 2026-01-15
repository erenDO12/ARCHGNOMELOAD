#!/bin/bash

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"

(
echo 10; echo "Dil seçimi yapılıyor..."

# 1. Dil / Locale (dinamik liste /etc/locale.gen üzerinden)
LOCALE=$(whiptail --title "Dil Seçimi" --menu "Kullanmak istediğiniz dili seçin:" 25 80 20 \
$(grep -E "UTF-8" /etc/locale.gen | sed 's/#//g' | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)

# Seçilen locale’yi aktif et
sed -i "s/^#\($LOCALE UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo 30; echo "Bölge ve zaman dilimi seçiliyor..."

# 2. Bölge / Timezone (dinamik liste)
TIMEZONE=$(whiptail --title "Zaman Dilimi Seçimi" --menu "Kullanmak istediğiniz zaman dilimini seçin:" 25 80 20 \
$(timedatectl list-timezones | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo 50; echo "Klavye düzeni seçiliyor..."

# 3. Klavye Düzeni (dinamik liste)
KEYMAP=$(whiptail --title "Klavye Düzeni Seçimi" --menu "Kullanmak istediğiniz klavye düzenini seçin:" 25 80 20 \
$(localectl list-keymaps | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo 70; echo "Ağ bağlantısı seçiliyor..."

# 4. Ağ / Bağlantı Türü
NETTYPE=$(whiptail --title "Bağlantı Türü" --menu "Hangi bağlantı türünü kullanmak istiyorsunuz?" 15 60 5 \
"wifi" "Kablosuz (Wi-Fi)" \
"ethernet" "Kablolu (Ethernet)" \
3>&1 1>&2 2>&3)

if [ "$NETTYPE" = "wifi" ]; then
  SSID_LIST=$(nmcli -t -f SSID dev wifi | grep -v '^$' | awk '{print $1 " " $1}')
  if [ -n "$SSID_LIST" ]; then
    WIFI=$(whiptail --title "Wi-Fi Seçimi" --menu "Bağlanmak istediğiniz Wi-Fi ağını seçin:" 20 70 15 $SSID_LIST 3>&1 1>&2 2>&3)
    WIFIPASS=$(whiptail --title "Wi-Fi Şifresi" --passwordbox "Seçilen Wi-Fi için şifre girin:" 10 60 3>&1 1>&2 2>&3)
    nmcli dev wifi connect "$WIFI" password "$WIFIPASS"
  else
    whiptail --title "Wi-Fi" --msgbox "Hiçbir aktif Wi-Fi ağı bulunamadı." 10 60
  fi
elif [ "$NETTYPE" = "ethernet" ]; then
  nmcli dev status | grep ethernet >/dev/null
  if [ $? -eq 0 ]; then
    nmcli con up id "$(nmcli -t -f NAME,TYPE con show | grep ethernet | cut -d: -f1 | head -n1)"
    whiptail --title "Ethernet" --msgbox "Ethernet bağlantısı etkinleştirildi." 10 60
  else
    whiptail --title "Ethernet" --msgbox "Ethernet arayüzü bulunamadı." 10 60
  fi
fi

echo 85; echo "Kullanıcı oluşturuluyor..."

# 5. Kullanıcı Adı ve Root Şifresi
USERNAME=$(whiptail --title "Kullanıcı Adı" --inputbox "Yeni kullanıcı adı girin:" 10 60 3>&1 1>&2 2>&3)
useradd -m -G wheel -s /bin/bash "$USERNAME"
USERPASS=$(whiptail --title "Kullanıcı Şifresi" --passwordbox "$USERNAME için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "$USERNAME:$USERPASS" | chpasswd
ROOTPASS=$(whiptail --title "Root Şifresi" --passwordbox "Root kullanıcısı için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "root:$ROOTPASS" | chpasswd

echo 90; echo "Masaüstü ortamı seçiliyor..."

# 6. Masaüstü Ortamı / WM Seçimi
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
"extra" "Ek Ortam Biçimleri (i3, Openbox, Awesome, Enlightenment)" \
3>&1 1>&2 2>&3)

case $DE in
  gnome) pacman -S --noconfirm gnome gdm; systemctl enable gdm ;;
  kde) pacman -S --noconfirm plasma kde-applications sddm; systemctl enable sddm ;;
  xfce4) pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  cinnamon) pacman -S --noconfirm cinnamon lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  mate) pacman -S --noconfirm mate mate-extra lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  lxqt) pacman -S --noconfirm lxqt openbox sddm; systemctl enable sddm ;;
  deepin) pacman -S --noconfirm deepin deepin-extra lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  budgie) pacman -S --noconfirm budgie-desktop lightdm lightdm-gtk-greeter; systemctl enable lightdm ;;
  hyperland) pacman -S --noconfirm hyperland ;;
  river) sudo -u "$USERNAME" yay -S --noconfirm river ;;
  sway) pacman -S --noconfirm sway ;;
  extra) pacman -S --noconfirm i3-wm i3status dmenu openbox obconf awesome enlightenment ;;
esac

echo 95; echo "Ek uygulamalar seçiliyor..."

# 7. Ek Uygulamalar Checklist
EXTRA=$(whiptail --title "Ek Uygulamalar" --checklist \
"Kurmak istediğiniz ek uygulamaları seçin:" 20 70 10 \
"firefox" "Web tarayıcı" OFF \
"pipewire" "Ses ve video altyapısı" OFF \
"vlc" "Medya oynatıcı" OFF \
"libreoffice" "Ofis paketi" OFF \
"thunderbird" "E-posta istemcisi" OFF \
"gimp" "Resim düzenleyici" OFF \
"neofetch" "Sistem bilgisi aracı" OFF \
"htop" "Sistem monitörü" OFF \
3>&1 1>&2 2>&3)

for app in $EXTRA; do
  case $app in
    \"firefox\") pacman -S --noconfirm firefox ;;
    \"pipewire\") pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack ;;
    \"vlc\") pacman -S --noconfirm vlc ;;
    \"libreoffice\") pacman -S --noconfirm libreoffice-fresh ;;
    \"thunderbird\") pacman -S --noconfirm thunderbird ;;
    \"gimp\") pacman -S --noconfirm gimp ;;
    \"neofetch\") pacman -S --noconfirm neofetch ;;
    \"htop\") pacman -S --noconfirm htop ;;
  esac
done

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

# ------------------------------------------------------------
# 8. Kurulum Sonrası İşlemler
# ------------------------------------------------------------
umount -R /mnt || true
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux + $DE hazır.\nSeçilen ek uygulamalar da kuruldu.\nLog: $LOGFILE" 10 60
clear

if whiptail --yesno "Kurulum tamamlandı! Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
