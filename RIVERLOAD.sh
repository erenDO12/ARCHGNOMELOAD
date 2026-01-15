#!/bin/bash
# ============================================================
# Arch Linux Otomatik Kurulum Scripti
# Dinamik seçim + Hyperland, Sway, Niri desteği
# ============================================================

TITLE="Arch Desktop Installer"
LOGFILE="install.log"

# ------------------------------------------------------------
# 1. Başlangıç onayı
# ------------------------------------------------------------
if ! whiptail --title "$TITLE" --yesno "Kuruluma başlamak istiyor musunuz?" 10 60; then
  clear; echo "Kurulum iptal edildi."; exit 1
fi

# ------------------------------------------------------------
# 2. Locale (Dil/Bölge) Dinamik Tarama
# ------------------------------------------------------------
LOCALES=$(locale -a | grep UTF-8)
MENU_OPTS=()
for l in $LOCALES; do MENU_OPTS+=("$l" ""); done
if [ ${#MENU_OPTS[@]} -eq 0 ]; then
  whiptail --msgbox "Hiç locale bulunamadı! Önce locale-gen çalıştırmanız gerekebilir." 10 60
  LANGSEL="en_US.UTF-8"
else
  LANGSEL=$(whiptail --title "$TITLE" --menu "Dil/Bölge Seçin:" 20 60 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)
fi

# ------------------------------------------------------------
# 3. WiFi Ağlarının Dinamik Tarama ve Bağlantı
# ------------------------------------------------------------
systemctl start NetworkManager
SSIDLIST=$(nmcli -t -f SSID dev wifi list | grep -v '^--')
MENU_OPTS=()
for s in $SSIDLIST; do [ -n "$s" ] && MENU_OPTS+=("$s" ""); done
if [ ${#MENU_OPTS[@]} -eq 0 ]; then
  whiptail --msgbox "Hiç WiFi ağı bulunamadı!" 10 50
else
  SSID=$(whiptail --title "$TITLE" --menu "WiFi Ağı Seçin:" 20 60 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)
  WIFIPASS=$(whiptail --title "$TITLE" --passwordbox "WiFi şifresi:" 10 50 3>&1 1>&2 2>&3)
  nmcli dev wifi connect "$SSID" password "$WIFIPASS"
fi

# ------------------------------------------------------------
# 4. Disklerin Dinamik Tarama ve Seçim
# ------------------------------------------------------------
DISKS=$(lsblk -dpno NAME | grep -E "/dev/(sd|nvme|vd)")
MENU_OPTS=()
for d in $DISKS; do MENU_OPTS+=("$d" ""); done
DISK=$(whiptail --title "$TITLE" --menu "Hedef Disk Seçin:" 20 60 10 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 5. Dosya Sistemi Seçimi
# ------------------------------------------------------------
FS=$(whiptail --title "$TITLE" --menu "Dosya Sistemi Seçin:" 15 60 5 \
  "ext4" "Klasik ve güvenilir" \
  "btrfs" "Snapshot destekli" \
  "xfs" "Yüksek performanslı" \
  3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 6. Masaüstü Ortamı / WM Seçimi
# ------------------------------------------------------------
DE=$(whiptail --title "$TITLE" --menu "Masaüstü Ortamı Seçin:" 20 60 15 \
  "gnome" "GNOME (modern)" \
  "kde" "KDE Plasma (özelleştirilebilir)" \
  "xfce" "Xfce (hafif)" \
  "lxqt" "LXQt (minimal)" \
  "mate" "MATE (klasik)" \
  "cinnamon" "Cinnamon (kullanıcı dostu)" \
  "deepin" "Deepin (estetik)" \
  "budgie" "Budgie (modern hafif)" \
  "openbox" "Openbox (çok hafif)" \
  "hyperland" "Hyperland (Wayland tiling)" \
  "sway" "Sway (i3 benzeri Wayland)" \
  "niri" "Niri (dinamik tiling WM)" \
  3>&1 1>&2 2>&3)

case $DE in
  gnome) DEPKGS="gnome gdm"; ENABLEDM="gdm" ;;
  kde) DEPKGS="plasma kde-applications sddm"; ENABLEDM="sddm" ;;
  xfce) DEPKGS="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  lxqt) DEPKGS="lxqt openbox sddm"; ENABLEDM="sddm" ;;
  mate) DEPKGS="mate mate-extra lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  cinnamon) DEPKGS="cinnamon lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  deepin) DEPKGS="deepin lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  budgie) DEPKGS="budgie-desktop lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  openbox) DEPKGS="openbox lightdm lightdm-gtk-greeter"; ENABLEDM="lightdm" ;;
  hyperland) DEPKGS="hyperland xorg-xwayland"; ENABLEDM="" ;;   # DM yok
  sway) DEPKGS="sway xorg-xwayland"; ENABLEDM="" ;;             # DM yok
  niri) DEPKGS="niri xorg-xwayland"; ENABLEDM="" ;;             # DM yok
esac

# ------------------------------------------------------------
# 7. Kullanıcı Bilgileri
# ------------------------------------------------------------
NEWUSER=$(whiptail --title "$TITLE" --inputbox "Yeni kullanıcı adı:" 10 50 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --title "$TITLE" --passwordbox "Kullanıcı şifresi:" 10 50 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --title "$TITLE" --passwordbox "Root şifresi:" 10 50 3>&1 1>&2 2>&3)

# ------------------------------------------------------------
# 8. Kurulum Süreci (Gauge ile ilerleme)
# ------------------------------------------------------------
(
echo 10; echo "Disk bölümlendirme ve formatlama..."
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

echo 55; echo "Temel sistem paketleri kuruluyor..."
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
[ -n \"$ENABLEDM\" ] && systemctl enable $ENABLEDM
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
useradd -m -G wheel -s /bin/bash $NEWUSER
echo \"$NEWUSER:$USERPASS\" | chpasswd
echo \"root:$ROOTPASS\" | chpasswd
"

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 60 0

# ------------------------------------------------------------
# 9. Kurulum Sonrası İşlemler
# ------------------------------------------------------------
umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux + $DE hazır.\nLog: $LOGFILE" 10 60
clear

# Yeniden başlatma onayı
if whiptail --yesno "Kurulum tamamlandı! Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
