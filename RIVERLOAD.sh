#!/bin/bash
set -euo pipefail

TITLE="Arch Kurulum Sihirbazı"
LOGFILE="/root/install.log"

# --- Locale seçimi (tam liste) ---
LOCALE=$(whiptail --title "Dil ve Locale Seçimi" --menu "Bir locale seçin:" 25 80 15 \
$(grep -E "^[a-z]" /usr/share/i18n/SUPPORTED | awk '{print $1 " \"" $1 "\""}') \
3>&1 1>&2 2>&3)

# --- Klavye seçimi (tam liste) ---
KEYMAP=$(whiptail --title "Klavye Düzeni" --menu "Bir klavye seçin:" 25 80 15 \
$(localectl list-keymaps | awk '{print $1 " \"" $1 "\""}') \
3>&1 1>&2 2>&3)

# --- Timezone seçimi (tam liste) ---
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

if [[ "$NETTYPE" == "static" ]]; then
  IPADDR=$(whiptail --inputbox "IP adresi:" 10 60 "192.168.1.100" 3>&1 1>&2 2>&3)
  GATEWAY=$(whiptail --inputbox "Gateway:" 10 60 "192.168.1.1" 3>&1 1>&2 2>&3)
  DNS=$(whiptail --inputbox "DNS:" 10 60 "8.8.8.8" 3>&1 1>&2 2>&3)
fi

if [[ "$NETTYPE" == "wifi" ]]; then
  SSID=$(whiptail --inputbox "WiFi SSID:" 10 60 3>&1 1>&2 2>&3)
  WIFIPASS=$(whiptail --passwordbox "WiFi Şifresi:" 10 60 3>&1 1>&2 2>&3)
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

# --- Chroot işlemleri ---
(
echo 25; echo "Chroot işlemleri başlıyor..."
arch-chroot /mnt bash -c "
set -euo pipefail

bootctl install

# Locale
if grep -q \"^#${LOCALE}\" /etc/locale.gen; then
  sed -i \"s/^#${LOCALE}/${LOCALE}/\" /etc/locale.gen
elif ! grep -q \"^${LOCALE}\" /etc/locale.gen; then
  echo \"${LOCALE}\" >> /etc/locale.gen
fi
echo \"LANG=${LOCALE}\" > /etc/locale.conf
locale-gen

# Hostname
echo \"${HOSTNAME}\" > /etc/hostname

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Keyboard
echo \"KEYMAP=${KEYMAP}\" > /etc/vconsole.conf
localectl set-x11-keymap ${KEYMAP}

# Bootloader
cat > /boot/loader/loader.conf <<EOL
default arch
timeout 3
console-mode keep
editor no
EOL

ROOTUUID=\$(blkid -s UUID -o value ${ROOTPART})
cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=\${ROOTUUID} rw quiet splash
EOL

# Ağ yapılandırması
if [[ \"${NETTYPE}\" == \"dhcp\" ]]; then
  systemctl enable NetworkManager
fi

if [[ \"${NETTYPE}\" == \"static\" ]]; then
  mkdir -p /etc/systemd/network
  cat > /etc/systemd/network/20-wired.network <<EOL
[Match]
Name=en*
[Network]
Address=${IPADDR}/24
Gateway=${GATEWAY}
DNS=${DNS}
EOL
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved
fi

if [[ \"${NETTYPE}\" == \"wifi\" ]]; then
  systemctl enable NetworkManager
  nmcli dev wifi connect \"${SSID}\" password \"${WIFIPASS}\" || true
fi

# Display manager
${DM_ENABLE}

# Hyprland greetd ayarı
if [[ \"${DESKTOP}\" == \"hyprland\" ]]; then
  pacman -Sy --noconfirm tuigreet
  mkdir -p /etc/greetd
  cat > /etc/greetd/config.toml <<EOL
[terminal]
vt = 1
[default_session]
command = \"tuigreet --time --cmd Hyprland\"
user = \"greeter\"
EOL
fi

# Sudo ve kullanıcı
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
useradd -m -G wheel -s /bin/bash ${NEWUSER}
echo \"${NEWUSER}:${USERPASS}\" | chpasswd
echo \"root:${ROOTPASS}\" | chpasswd

# Enlightenment özel ayar
if [[ \"${DESKTOP}\" == \"enlightenment\" ]]; then
  mkdir -p /home/${NEWUSER}/.e
  cat > /home/${NEWUSER}/.e/e.src <<EOL
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
EOL
  chown -R ${NEWUSER}:${NEWUSER} /home/${NEWUSER}/.e
fi
"
echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 70 0

umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux hazır.\nLog: $LOGFILE" 10 70
clear

if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi
