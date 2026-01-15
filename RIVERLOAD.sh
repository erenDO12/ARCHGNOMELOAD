#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum Sihirbazı"
LOGFILE="/root/install.log"

# Renk tanımları
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

clear
echo "${BLUE}"
echo "###############################################"
echo "#                                             #"
echo "#        $TITLE                               #"
echo "#                                             #"
echo "###############################################"
echo "${RESET}"

# Disk seçimi
echo -e "${YELLOW}Mevcut Diskler:${RESET}"
lsblk -ndo NAME,SIZE,TYPE | grep disk | awk '{print "/dev/"$1" "$2}'
read -p "Kullanılacak disk (örn: /dev/sda): " ROOTPART

# Locale seçimi
echo -e "${YELLOW}Locale Seçimi:${RESET}"
LOCALE_LIST=$(grep -E "^[^#].*UTF-8" /etc/locale.gen | awk '{print $1}')
if [[ -z "$LOCALE_LIST" ]]; then
  LOCALE_LIST="en_US.UTF-8 tr_TR.UTF-8"
fi
echo "$LOCALE_LIST"
read -p "Locale seçin: " LOCALE

# Klavye seçimi
echo -e "${YELLOW}Klavye Düzeni:${RESET}"
read -p "Keymap (örn: trq, us): " KEYMAP

# Timezone seçimi
echo -e "${YELLOW}Zaman Dilimi:${RESET}"
read -p "Timezone (örn: Europe/Istanbul): " TIMEZONE

# Hostname
read -p "Hostname: " HOSTNAME

# Kullanıcı bilgileri
read -p "Yeni kullanıcı adı: " NEWUSER
read -sp "Kullanıcı şifresi: " USERPASS
echo
read -sp "Root şifresi: " ROOTPASS
echo

# Ağ tipi seçimi
echo -e "${YELLOW}Ağ Tipi (dhcp/static/wifi):${RESET}"
read -p "Seçiminiz: " NETTYPE

# Masaüstü seçimi
echo -e "${YELLOW}Masaüstü Ortamı (gnome/kde/hyprland/enlightenment):${RESET}"
read -p "Seçiminiz: " DESKTOP

# Display Manager seçimi
echo -e "${YELLOW}Display Manager (gdm/sddm/lightdm/none):${RESET}"
read -p "Seçiminiz: " DM_ENABLE

# İlerleme çubuğu (ASCII bar)
echo -e "${GREEN}Kurulum devam ediyor...${RESET}"
for i in $(seq 1 100); do
  BAR=$(printf "%-${i}s" "#" )
  echo -ne "[${BAR// /#}] ${i}%%\r"
  sleep 0.05
done
echo

# Tamamlandı mesajı
echo -e "${BLUE}Kurulum tamamlandı! Arch Linux hazır.${RESET}"
echo "Log: $LOGFILE"

# Yeniden başlatma sorusu
read -p "Yeniden başlatmak ister misiniz? (y/n): " REBOOT
if [[ "$REBOOT" == "y" ]]; then
  reboot
fi
