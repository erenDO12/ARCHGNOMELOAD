#!/bin/bash

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"

# ------------------------------------------------------------
# 1. Dil Seçimi
# ------------------------------------------------------------
LOCALE=$(whiptail --title "Dil Seçimi" --menu "Kullanmak istediğiniz dili seçin:" 25 80 20 \
$(grep -E "UTF-8" /etc/locale.gen | sed 's/#//g' | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
sed -i "s/^#\($LOCALE UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# ------------------------------------------------------------
# 2. Zaman Dilimi Seçimi
# ------------------------------------------------------------
TIMEZONE=$(whiptail --title "Zaman Dilimi Seçimi" --menu "Kullanmak istediğiniz zaman dilimini seçin:" 25 80 20 \
$(timedatectl list-timezones | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# ------------------------------------------------------------
# 3. Klavye Düzeni Seçimi
# ------------------------------------------------------------
KEYMAP=$(whiptail --title "Klavye Düzeni Seçimi" --menu "Kullanmak istediğiniz klavye düzenini seçin:" 25 80 20 \
$(localectl list-keymaps | awk '{print $1 " " $1}') \
3>&1 1>&2 2>&3)
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# ------------------------------------------------------------
# 4. Ağ Bağlantısı
# ------------------------------------------------------------
NETTYPE=$(whiptail --title "Ağ Bağlantısı" --menu "Bağlantı türünü seçin:" 15 60 5 \
"wifi" "Kablosuz (Wi-Fi)" \
"ethernet" "Kablolu (Ethernet)" \
"modem" "Mobil Modem (3G/4G)" \
3>&1 1>&2 2>&3)

if [ "$NETTYPE" = "wifi" ]; then
  DEV=$(iwctl device list | awk '/wlan/{print $1}' | head -n1)
  iwctl station "$DEV" scan
  SSID_LIST=$(iwctl station "$DEV" get-networks | awk 'NR>4 {print $2 " " $2}')
  WIFI=$(whiptail --title "Wi-Fi Seçimi" --menu "Bağlanmak istediğiniz Wi-Fi ağını seçin:" 20 70 15 $SSID_LIST 3>&1 1>&2 2>&3)
  WIFIPASS=$(whiptail --title "Wi-Fi Şifresi" --passwordbox "Seçilen Wi-Fi için şifre girin:" 10 60 3>&1 1>&2 2>&3)
  iwctl --passphrase "$WIFIPASS" station "$DEV" connect "$WIFI"
elif [ "$NETTYPE" = "ethernet" ]; then
  ip link set eth0 up
  dhcpcd eth0
elif [ "$NETTYPE" = "modem" ]; then
  pacman -S --noconfirm modemmanager usb_modeswitch networkmanager
  systemctl enable ModemManager
  systemctl enable NetworkManager
fi

# ------------------------------------------------------------
# 5. Kullanıcı Oluşturma
# ------------------------------------------------------------
USERNAME=$(whiptail --title "Kullanıcı Adı" --inputbox "Yeni kullanıcı adı girin:" 10 60 3>&1 1>&2 2>&3)
useradd -m -G wheel -s /bin/bash "$USERNAME"
USERPASS=$(whiptail --title "Kullanıcı Şifresi" --passwordbox "$USERNAME için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "$USERNAME:$USERPASS" | chpasswd
ROOTPASS=$(whiptail --title "Root Şifresi" --passwordbox "Root için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "root:$ROOTPASS" | chpasswd

# ------------------------------------------------------------
# 6. Masaüstü Ortamı Seçimi
# ------------------------------------------------------------
DE=$(whiptail --title "Masaüstü Ortamı Seçimi" --menu "Kurmak istediğiniz masaüstü ortamını seçin:" 20 70 15 \
"gnome" "GNOME" \
"kde" "KDE Plasma" \
"xfce4" "XFCE" \
"cinnamon" "Cinnamon" \
"mate" "MATE" \
"lxqt" "LXQt" \
"deepin" "Deepin" \
"budgie" "Budgie" \
"hyperland" "Hyperland (Wayland)" \
"sway" "Sway (Wayland)" \
"river" "River (Wayland, yay ile)" \
3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 7. Ek Uygulamalar
# ------------------------------------------------------------
EXTRA=$(whiptail --title "Ek Uygulamalar" --checklist \
"Kurmak istediğiniz ek uygulamaları seçin:" 20 70 10 \
$(pacman -Sl extra | awk '{print $2 " " $2 " OFF"}') \
3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 8. Kurulum İlerleme Barı
# ------------------------------------------------------------
(
echo 10; echo "Dil ayarları uygulanıyor..."
echo 30; echo "Zaman dilimi ayarlanıyor..."
echo 50; echo "Klavye düzeni kaydediliyor..."
echo 70; echo "Ağ yapılandırılıyor..."
echo 85; echo "Kullanıcı hesapları oluşturuluyor..."
echo 90; echo "Masaüstü ortamı kuruluyor..."
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
  sway) pacman -S --noconfirm sway ;;
  river) pacman -S --noconfirm yay && sudo -u "$USERNAME" yay -S --noconfirm river ;;
esac
echo 95; echo "Ek uygulamalar yükleniyor..."
for app in $EXTRA; do
  pacman -S --noconfirm $(echo $app | tr -d '"')
done
echo 100; echo "Kurulum tamamlandı!"
) | whiptail --title "Kurulum İlerleme Durumu" --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

# ------------------------------------------------------------
# 9. Kurulum Sonrası
# ------------------------------------------------------------
umount -R /mnt || true
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux + $DE hazır.\nSeçilen ek uygulamalar da kuruldu.\nLog: $LOGFILE" 10 60
clear

if whiptail --yesno "Kurulum tamamlandı! Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
