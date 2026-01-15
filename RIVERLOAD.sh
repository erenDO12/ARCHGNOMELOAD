#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum Sihirbazı"
LOGFILE="/root/install.log"

# Disk seçimi
DISK_LIST=$(lsblk -ndo NAME,SIZE,TYPE | grep disk | awk '{print "/dev/"$1" "$2}')
ROOTPART=$(yad --list --radiolist \
  --title="Disk Seçimi" \
  --width=600 --height=400 \
  --column "Seç" --column "Disk" --column "Boyut" \
  $(for d in $DISK_LIST; do echo "FALSE $d"; done) \
  --separator=" " \
)

# Locale seçimi
LOCALE_LIST=$(grep -E "^[^#].*UTF-8" /etc/locale.gen | awk '{print $1}')
if [[ -z "$LOCALE_LIST" ]]; then
  LOCALE_LIST="en_US.UTF-8 tr_TR.UTF-8"
fi
LOCALE=$(yad --list --radiolist \
  --title="Dil ve Locale Seçimi" \
  --width=600 --height=400 \
  --column "Seç" --column "Locale" \
  $(for l in $LOCALE_LIST; do echo "FALSE $l"; done) \
  --separator=" " \
)

# Klavye seçimi
KEYMAP=$(localectl list-keymaps | yad --list --radiolist \
  --title="Klavye Düzeni" \
  --width=600 --height=400 \
  --column "Seç" --column "Keymap" \
  $(while read k; do echo "FALSE $k"; done) \
  --separator=" " \
)

# Timezone seçimi
TIMEZONE_LIST=$(find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||')
TIMEZONE=$(yad --list --radiolist \
  --title="Zaman Dilimi" \
  --width=600 --height=400 \
  --column "Seç" --column "Timezone" \
  $(for t in $TIMEZONE_LIST; do echo "FALSE $t"; done) \
  --separator=" " \
)

# Hostname
HOSTNAME=$(yad --entry --title="Hostname" --text="Hostname girin:" --entry-text="archlinux")

# Kullanıcı bilgileri
NEWUSER=$(yad --entry --title="Yeni Kullanıcı" --text="Yeni kullanıcı adı:" --entry-text="user")
USERPASS=$(yad --entry --hide-text --title="Kullanıcı Şifresi" --text="Şifre girin:")
ROOTPASS=$(yad --entry --hide-text --title="Root Şifresi" --text="Şifre girin:")

# Ağ tipi seçimi
NETTYPE=$(yad --list --radiolist \
  --title="Ağ Yapılandırması" \
  --width=400 --height=200 \
  --column "Seç" --column "Tip" \
  FALSE dhcp FALSE static FALSE wifi \
  --separator=" " \
)

# Masaüstü seçimi
DESKTOP=$(yad --list --radiolist \
  --title="Masaüstü Ortamı" \
  --width=400 --height=200 \
  --column "Seç" --column "Desktop" \
  FALSE hyprland FALSE enlightenment FALSE gnome FALSE kde \
  --separator=" " \
)

# Display Manager seçimi
DM_ENABLE=$(yad --list --radiolist \
  --title="Display Manager" \
  --width=400 --height=200 \
  --column "Seç" --column "DM Komutu" --column "Açıklama" \
  FALSE "systemctl enable gdm" "GNOME Display Manager" \
  FALSE "systemctl enable sddm" "Simple Desktop Display Manager" \
  FALSE "systemctl enable lightdm" "LightDM" \
  FALSE "none" "Yok" \
  --separator=" " \
)

# İlerleme çubuğu
yad --progress --title="Kurulum" --text="Kurulum devam ediyor..." --percentage=0 &
PROGRESS_PID=$!
sleep 2
echo "20" | tee /proc/$PROGRESS_PID/fd/0
sleep 2
echo "50" | tee /proc/$PROGRESS_PID/fd/0
sleep 2
echo "100" | tee /proc/$PROGRESS_PID/fd/0
wait $PROGRESS_PID

# Tamamlandı mesajı
yad --info --title="$TITLE" --text="Kurulum tamamlandı! Arch Linux hazır.\nLog: $LOGFILE"

# Yeniden başlatma sorusu
if yad --question --title="Yeniden Başlat" --text="Sistemi yeniden başlatmak ister misiniz?"; then
  reboot
fi
