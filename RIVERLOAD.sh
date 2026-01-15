#!/bin/bash

TITLE="Arch Kurulum"
LOGFILE="/root/kurulum.log"

(
echo 10; echo "Dil seçimi yapılıyor..."

# 1. Dil / Locale
LOCALE=$(whiptail --title "Dil Seçimi" --menu "Kullanmak istediğiniz dili seçin:" 20 70 15 $(locale -a | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
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
  echo 'export GTK_IM_MODULE=ibus' >> /etc/environment
  echo 'export QT_IM_MODULE=ibus' >> /etc/environment
  echo 'export XMODIFIERS=@im=ibus' >> /etc/environment
elif [ "$INPUT" = "fcitx" ]; then
  echo 'export GTK_IM_MODULE=fcitx' >> /etc/environment
  echo 'export QT_IM_MODULE=fcitx' >> /etc/environment
  echo 'export XMODIFIERS=@im=fcitx' >> /etc/environment
fi

echo 85; echo "Wi-Fi ağları taranıyor..."

# 5. Ağ / Wi-Fi
SSID_LIST=$(nmcli -t -f SSID dev wifi | grep -v '^$' | awk '{print $1 " " $1}')
WIFI=$(whiptail --title "Wi-Fi Seçimi" --menu "Bağlanmak istediğiniz Wi-Fi ağını seçin:" 20 70 15 $SSID_LIST 3>&1 1>&2 2>&3)
WIFIPASS=$(whiptail --title "Wi-Fi Şifresi" --passwordbox "Seçilen Wi-Fi için şifre girin:" 10 60 3>&1 1>&2 2>&3)
nmcli dev wifi connect "$WIFI" password "$WIFIPASS"

echo 95; echo "Kullanıcı oluşturuluyor..."

# 6. Kullanıcı Adı ve Root Şifresi
USERNAME=$(whiptail --title "Kullanıcı Adı" --inputbox "Yeni kullanıcı adı girin:" 10 60 3>&1 1>&2 2>&3)
useradd -m -G wheel -s /bin/bash "$USERNAME"

USERPASS=$(whiptail --title "Kullanıcı Şifresi" --passwordbox "$USERNAME için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "$USERNAME:$USERPASS" | chpasswd

ROOTPASS=$(whiptail --title "Root Şifresi" --passwordbox "Root kullanıcısı için şifre girin:" 10 60 3>&1 1>&2 2>&3)
echo "root:$ROOTPASS" | chpasswd

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

# ------------------------------------------------------------
# 9. Kurulum Sonrası İşlemler
# ------------------------------------------------------------
umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux hazır.\nLog: $LOGFILE" 10 60
clear

if whiptail --yesno "Kurulum tamamlandı! Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
