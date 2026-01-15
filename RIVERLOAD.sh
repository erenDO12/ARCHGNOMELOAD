#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum Sihirbazı"
LOGFILE="/root/install.log"

# Tema ayarı (beyaz yazı, siyah arka plan)
export NEWT_COLORS='
root=white,black
border=white,black
textbox=white,black
button=black,white
entry=white,black
title=white,black
'

# Diskleri listele ve seçim yaptır
DISK=$(lsblk -ndo NAME,SIZE,TYPE | grep disk | awk '{print "/dev/"$1 " \"" $1 " (" $2 ")\""}')

ROOTPART=$(whiptail --title "Disk Seçimi" --menu "Root partition seçin:" 25 80 15 \
$DISK \
3>&1 1>&2 2>&3)

# Locale seçimi
LOCALE=$(whiptail --title "Dil ve Locale Seçimi" --menu "Bir locale seçin:" 25 80 15 \
$(grep -E "^[^#].*UTF-8" /etc/locale.gen | awk '{print $1 " \"" $1 "\""}') \
3>&1 1>&2 2>&3)

# Klavye seçimi
KEYMAP=$(whiptail --title "Klavye Düzeni (Konsol)" --menu "Bir klavye seçin:" 25 80 15 \
$(localectl list-keymaps | awk '{print $1 " \"" $1 "\""}') \
3>&1 1>&2 2>&3)

# Timezone seçimi
TIMEZONE=$(whiptail --title "Zaman Dilimi" --menu "Bir timezone seçin:" 25 80 15 \
$(find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | awk '{print $1 " \"" $1 "\""}') \
3>&1 1>&2 2>&3)

# Hostname
HOSTNAME=$(whiptail --inputbox "Hostname girin:" 10 60 "archlinux" 3>&1 1>&2 2>&3)

# Kullanıcı bilgileri
NEWUSER=$(whiptail --inputbox "Yeni kullanıcı adı:" 10 60 "user" 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --passwordbox "Yeni kullanıcı için şifre:" 10 60 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --passwordbox "Root için şifre:" 10 60 3>&1 1>&2 2>&3)

# Ağ tipi seçimi
NETTYPE=$(whiptail --title "Ağ Yapılandırması" --menu "Bir ağ tipi seçin:" 20 70 10 \
  "dhcp" "DHCP (otomatik)" \
  "static" "Statik IP" \
  "wifi" "Kablosuz Bağlantı" \
  3>&1 1>&2 2>&3)

# Ağ arayüzü ve WiFi SSID seçimi
if [[ "$NETTYPE" == "wifi" ]]; then
  INTERFACES=$(ls /sys/class/net | grep -E '^wl')
  IFACE=$(whiptail --title "WiFi Arayüzü Seçimi" --menu "Bir WiFi arayüzü seçin:" 20 70 10 \
  $(for i in $INTERFACES; do echo "$i $i"; done) \
  3>&1 1>&2 2>&3)

  SSID_LIST=$(nmcli -t -f SSID dev wifi list ifname "$IFACE" | grep -v '^$' | sort -u)
  SSID=$(whiptail --title "WiFi Ağları" --menu "Bir WiFi ağı seçin:" 20 70 10 \
  $(for s in $SSID_LIST; do echo "$s $s"; done) \
  3>&1 1>&2 2>&3)

  WIFIPASS=$(whiptail --passwordbox "WiFi Şifresi (SSID: $SSID)" 10 60 3>&1 1>&2 2>&3)
else
  INTERFACES=$(ls /sys/class/net | grep -E '^(en|eth|eno|ens|enp)')
  IFACE=$(whiptail --title "Kablolu Arayüz Seçimi" --menu "Bir ağ arayüzü seçin:" 20 70 10 \
  $(for i in $INTERFACES; do echo "$i $i"; done) \
  3>&1 1>&2 2>&3)
fi

if [[ "$NETTYPE" == "static" ]]; then
  IPADDR=$(whiptail --inputbox "IP adresi (CIDR /24 varsayılacak):" 10 60 "192.168.1.100" 3>&1 1>&2 2>&3)
  GATEWAY=$(whiptail --inputbox "Gateway:" 10 60 "192.168.1.1" 3>&1 1>&2 2>&3)
  DNS=$(whiptail --inputbox "DNS:" 10 60 "8.8.8.8" 3>&1 1>&2 2>&3)
fi

# Masaüstü seçimi
DESKTOP=$(whiptail --title "Masaüstü Ortamı" --menu "Bir masaüstü seçin:" 20 70 10 \
  "hyprland" "Hyprland" \
  "enlightenment" "Enlightenment" \
  "gnome" "GNOME" \
  "kde" "KDE Plasma" \
  3>&1 1>&2 2>&3)

# Display Manager seçimi
DM_ENABLE=$(whiptail --title "Display Manager" --menu "Bir DM seçin:" 20 70 10 \
  "systemctl enable gdm" "GNOME Display Manager" \
  "systemctl enable sddm" "Simple Desktop Display Manager" \
  "systemctl enable lightdm" "LightDM" \
  "true" "Yok" \
  3>&1 1>&2 2>&3)

# --- Chroot işlemleri ve ilerleme ---
(
echo 5; echo "Bootloader kuruluyor..."
arch-chroot /mnt bootctl install

# ... (senin önceki kurulum adımların burada aynı şekilde devam ediyor)
# Bu kısımda sadece disk seçimi ve tema değişiklikleri eklendi.
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 70 0

umount -R /mnt || true
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux hazır.\nLog: $LOGFILE" 10 70
clear

if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
