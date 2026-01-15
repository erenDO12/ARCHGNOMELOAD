#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum Sihirbazı"
LOGFILE="/root/install.log"

# Root partition seçimi
ROOTPART=$(whiptail --inputbox "Root partition cihaz yolunu girin (örn: /dev/nvme0n1p3 veya /dev/sda2):" 10 70 "/dev/sda2" 3>&1 1>&2 2>&3)

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

echo 15; echo "Locale ayarlanıyor..."
arch-chroot /mnt bash -c "
if grep -q \"^#${LOCALE}\" /etc/locale.gen; then
  sed -i \"s/^#${LOCALE}/${LOCALE}/\" /etc/locale.gen
elif ! grep -q \"^${LOCALE}\" /etc/locale.gen; then
  echo \"${LOCALE}\" >> /etc/locale.gen
fi
echo \"LANG=${LOCALE}\" > /etc/locale.conf
locale-gen
"

echo 25; echo "Hostname ayarlanıyor..."
echo "${HOSTNAME}" | arch-chroot /mnt tee /etc/hostname >/dev/null

echo 35; echo "Timezone ayarlanıyor..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
arch-chroot /mnt hwclock --systohc

echo 45; echo "Klavye ayarlanıyor..."
echo "KEYMAP=${KEYMAP}" | arch-chroot /mnt tee /etc/vconsole.conf >/dev/null
arch-chroot /mnt localectl set-keymap ${KEYMAP} || true

echo 55; echo "Bootloader yapılandırılıyor..."
ROOTUUID=$(blkid -s UUID -o value ${ROOTPART})
arch-chroot /mnt bash -c "cat > /boot/loader/loader.conf <<EOL
default arch
timeout 3
console-mode keep
editor no
EOL"
arch-chroot /mnt bash -c "cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOTUUID} rw quiet splash
EOL"

echo 65; echo "Ağ yapılandırması yapılıyor..."
if [[ "$NETTYPE" == "dhcp" ]]; then
  arch-chroot /mnt systemctl enable NetworkManager
fi
if [[ "$NETTYPE" == "static" ]]; then
  arch-chroot /mnt bash -c "mkdir -p /etc/systemd/network && cat > /etc/systemd/network/20-wired.network <<EOL
[Match]
Name=${IFACE}
[Network]
Address=${IPADDR}/24
Gateway=${GATEWAY}
DNS=${DNS}
EOL"
  arch-chroot /mnt systemctl enable systemd-networkd
  arch-chroot /mnt systemctl enable systemd-resolved
fi
if [[ "$NETTYPE" == "wifi" ]]; then
  arch-chroot /mnt systemctl enable NetworkManager
  arch-chroot /mnt bash -c "nmcli dev wifi connect \"${SSID}\" password \"${WIFIPASS}\" ifname \"${IFACE}\" || true"
fi

echo 75; echo "Display Manager etkinleştiriliyor..."
arch-chroot /mnt bash -c "${DM_ENABLE}"

echo 85; echo "Masaüstü ortamı ayarlanıyor..."
if [[ "${DESKTOP}" == "hyprland" ]]; then
  arch-chroot /mnt pacman -Sy --noconfirm tuigreet || true
  arch-chroot /mnt bash -c "mkdir -p /etc/greetd && cat > /etc/greetd/config.toml <<EOL
[terminal]
vt = 1
[default_session]
command = \"tuigreet --time --cmd Hyprland\"
user = \"greeter\"
EOL"
fi

if [[ "${DESKTOP}" == "enlightenment" ]]; then
  arch-chroot /mnt bash -c "mkdir -p /home/${NEWUSER}/.e && cat > /home/${NEWUSER}/.e/e.src <<EOL
group \"shelves\" struct {
  group \"shelf\" struct {
    value \"name\" string: \"default\";
    value \"style\" string: \"default\";
    group \"contents\" list {
      group \"item\" struct {
        value \"name\" string: \"Network\";
      }
    }
  }
}
EOL"
  arch-chroot /mnt chown -R ${NEWUSER}:${NEWUSER} /home/${NEWUSER}/.e
fi

echo 95; echo "Kullanıcı ve sudo ayarlanıyor..."
arch-chroot /mnt bash -c "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers"
arch-chroot /mnt useradd -m -G wheel -s /bin/bash ${NEWUSER}
echo "${NEWUSER}:${USERPASS}" | arch-chroot /mnt chpasswd
echo "root:${ROOTPASS}" | arch-chroot /mnt chpasswd

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 70 0

umount -R /mnt || true
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux hazır.\nLog: $LOGFILE" 10 70
clear

if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
