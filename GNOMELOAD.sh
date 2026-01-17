#!/bin/bash
set -euo pipefail

TITLE="Arch GNOME Installer"

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
  echo "Bu script root olarak çalıştırılmalıdır."
  exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
  echo "whiptail yüklü değil. 'pacman -Sy --noconfirm libnewt' ile yükleyin."
  exit 1
fi

# Disk seçimi
DISK=$(whiptail --title "$TITLE" --inputbox "Hedef disk (örn: /dev/sda):" 10 60 3>&1 1>&2 2>&3)

# Kullanıcı bilgileri
NEWUSER=$(whiptail --title "$TITLE" --inputbox "Yeni kullanıcı adı:" 10 60 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --title "$TITLE" --passwordbox "Kullanıcı şifresi:" 10 60 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --title "$TITLE" --passwordbox "Root şifresi:" 10 60 3>&1 1>&2 2>&3)

# Dil/locale seçimi
LOCALE=$(whiptail --title "$TITLE" --menu "Dil/Locale Seçin:" 20 70 10 \
"en_US.UTF-8" "English (US)" \
"tr_TR.UTF-8" "Türkçe" \
3>&1 1>&2 2>&3)

# Klavye seçimi
KEYMAP=$(whiptail --title "$TITLE" --menu "Klavye Düzeni Seçin:" 20 70 10 \
"us" "US QWERTY" \
"trq" "Türkçe Q" \
"trf" "Türkçe F" \
3>&1 1>&2 2>&3)

# Zaman dilimi seçimi
TIMEZONE=$(whiptail --title "$TITLE" --menu "Zaman Dilimi Seçin:" 20 70 10 \
"Europe/Istanbul" "Türkiye" \
"Europe/Berlin" "Almanya" \
"UTC" "UTC" \
3>&1 1>&2 2>&3)

# Disk bölümlendirme
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary 512MiB 100%

BOOTPART=$(ls "${DISK}"* | grep -E "${DISK}p?1$")
ROOTPART=$(ls "${DISK}"* | grep -E "${DISK}p?2$")

mkfs.fat -F32 "$BOOTPART"
mkfs.ext4 -F "$ROOTPART"

mount "$ROOTPART" /mnt
mkdir -p /mnt/boot
mount "$BOOTPART" /mnt/boot

# Temel sistem + GNOME
pacstrap /mnt base linux linux-firmware gnome gdm networkmanager sudo vim nano

genfstab -U /mnt >> /mnt/etc/fstab

# Chroot işlemleri heredoc ile
arch-chroot /mnt /bin/bash <<EOF
bootctl install

# Locale
if ! grep -q "^${LOCALE}" /etc/locale.gen; then
  echo "${LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Hostname
echo "archpc" > /etc/hostname

# Timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Keyboard
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
localectl set-x11-keymap ${KEYMAP}

# Bootloader entry
ROOTUUID=\$(blkid -s UUID -o value ${ROOTPART})
cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=\${ROOTUUID} rw quiet
EOL

# Ağ
systemctl enable NetworkManager

# GNOME
systemctl enable gdm

# Kullanıcı ve root şifreleri
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
useradd -m -G wheel -s /bin/bash ${NEWUSER}
echo "${NEWUSER}:${USERPASS}" | chpasswd
echo "root:${ROOTPASS}" | chpasswd
EOF

umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Yeniden başlatabilirsiniz." 10 60
