#!/bin/bash

TITLE="Arch Desktop Installer"
LOGFILE="install.log"

# Başlangıç onayı
if ! whiptail --title "$TITLE" --yesno "Kuruluma başlamak istiyor musunuz?" 10 60; then
  clear; echo "Kurulum iptal edildi."; exit 1
fi

# Dil/Bölge seçimi
LOCALES=$(locale -a | grep UTF-8)
MENU_OPTS=()
for l in $LOCALES; do MENU_OPTS+=("$l" ""); done
LANGSEL=$(whiptail --title "$TITLE" --menu "Dil/Bölge Seçin:" 20 60 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

# WiFi SSID seçimi
SSIDLIST=$(nmcli -t -f SSID dev wifi list | grep -v '^--')
MENU_OPTS=()
for s in $SSIDLIST; do [ -n "$s" ] && MENU_OPTS+=("$s" ""); done
SSID=$(whiptail --title "$TITLE" --menu "WiFi Ağı Seçin:" 20 60 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)
WIFIPASS=$(whiptail --title "$TITLE" --passwordbox "WiFi şifresi:" 10 50 3>&1 1>&2 2>&3)
nmcli dev wifi connect "$SSID" password "$WIFIPASS"

# Disk seçimi
DISKS=$(lsblk -dpno NAME | grep -E "/dev/sd|/dev/nvme")
MENU_OPTS=()
for d in $DISKS; do MENU_OPTS+=("$d" ""); done
DISK=$(whiptail --title "$TITLE" --menu "Hedef Disk Seçin:" 20 60 10 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

# Dosya sistemi seçimi
FS=$(whiptail --title "$TITLE" --menu "Dosya Sistemi Seçin:" 15 60 5 "ext4" "" "btrfs" "" "xfs" "" 3>&1 1>&2 2>&3)

# Masaüstü ortamı seçimi
DE=$(whiptail --title "$TITLE" --menu "Masaüstü Ortamı Seçin:" 20 60 12 \
  "gnome" "GNOME" \
  "kde" "KDE Plasma" \
  "xfce" "Xfce" \
  "lxqt" "LXQt" \
  "mate" "MATE" \
  "cinnamon" "Cinnamon" \
  "deepin" "Deepin" \
  "enlightenment" "Enlightenment" \
  "budgie" "Budgie" \
  "openbox" "Openbox (hafif)" \
  3>&1 1>&2 2>&3)

case $DE in
  gnome) DEPKGS="gnome gdm"; ENABLEDM="gdm" ;;
  kde) DEPKGS="plasma kde-applications sddm"; ENABLEDM="sddm" ;;
  xfce) DEPKGS="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  lxqt) DEPKGS="lxqt openbox sddm"; ENABLEDM="sddm" ;;
  mate) DEPKGS="mate mate-extra lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  cinnamon) DEPKGS="cinnamon lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  deepin) DEPKGS="deepin lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  enlightenment) DEPKGS="enlightenment lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  budgie) DEPKGS="budgie-desktop lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  openbox) DEPKGS="openbox lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
esac

# Kullanıcı bilgileri
NEWUSER=$(whiptail --title "$TITLE" --inputbox "Yeni kullanıcı adı:" 10 50 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --title "$TITLE" --passwordbox "Kullanıcı şifresi:" 10 50 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --title "$TITLE" --passwordbox "Root şifresi:" 10 50 3>&1 1>&2 2>&3)

# Gauge ile kurulum
(
echo 10; echo "Disk bölümlendirme..."
umount -R /mnt 2>/dev/null; mkdir -p /mnt
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 512MiB
parted -s $DISK set 1 boot on
parted -s $DISK mkpart primary 512MiB 100%
BOOTPART=$(ls ${DISK}* | grep -E "${DISK}p?1$")
ROOTPART=$(ls ${DISK}* | grep -E "${DISK}p?2$")
mkfs.fat -F32 $BOOTPART
case $FS in ext4) mkfs.ext4 -F $ROOTPART ;; btrfs) mkfs.btrfs -f $ROOTPART ;; xfs) mkfs.xfs -f $ROOTPART ;; esac

echo 25; echo "Disk mount ediliyor..."
mount $ROOTPART /mnt; mkdir -p /mnt/boot; mount $BOOTPART /mnt/boot

echo 40; echo "Mirror listesi güncelleniyor..."
pacman -Sy --noconfirm

echo 55; echo "Temel sistem kuruluyor..."
pacstrap /mnt base linux linux-firmware nano sudo \
  vim git unzip plymouth systemd \
  networkmanager network-manager-applet \
  $DEPKGS

echo 70; echo "fstab oluşturuluyor..."
genfstab -U /mnt >> /mnt/etc/fstab

echo 85; echo "Chroot işlemleri..."
arch-chroot /mnt /bin/bash -c "
bootctl install
echo LANG=$LANGSEL > /etc/locale.conf
echo arch-desktop > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc
systemctl enable NetworkManager
systemctl enable $ENABLEDM
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
useradd -m -G wheel -s /bin/bash $NEWUSER
echo \"$NEWUSER:$USERPASS\" | chpasswd
echo \"root:$ROOTPASS\" | chpasswd
"

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux + $DE hazır.\nLog: $LOGFILE" 10 60
clear

# Yeniden başlatma onayı
if whiptail --yesno "Kurulum tamamlandı! Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
