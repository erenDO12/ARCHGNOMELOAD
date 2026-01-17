




Bugün
Şunu dediniz:
Arch Linux net install ISO ya sıfırdan parted system d ile Gnome kurulumunu göster
Copilot şunu dedi:
Harika bir konu seçtin ⚡. Arch Linux’u netinstall ISO üzerinden sıfırdan kurmak, özellikle parted ile disk bölümlendirme ve systemd init sistemiyle GNOME masaüstünü kurmak, hem öğretici hem de pratik bir süreçtir. Sana adım adım bir rehber hazırladım:

🖥️ 1. ISO ile Boot Et
Arch Linux netinstall ISO’yu indirip USB’ye yaz.

BIOS/UEFI’den USB ile boot et.

İnternete bağlan (iwctl veya ip link ile kontrol et).

💽 2. Disk Bölümlendirme (parted)
Örnek: tek disk /dev/sda

bash


Kopyala
parted /dev/sda
mklabel gpt
mkpart ESP fat32 1MiB 512MiB
set 1 boot on
mkpart primary ext4 512MiB 100%
quit
ESP (EFI System Partition): 512 MB, FAT32

Root: kalan alan, ext4

Formatla:

bash


Kopyala
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
Mount et:

bash


Kopyala
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
📦 3. Temel Sistem Kurulumu
bash


Kopyala
pacstrap /mnt base linux linux-firmware vim nano networkmanager systemd
📂 4. Fstab ve Chroot
bash


Kopyala
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
⚙️ 5. Sistem Ayarları
Hostname:

bash


Kopyala
echo archpc > /etc/hostname
Locales:

bash


Kopyala
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
Saat:

bash


Kopyala
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc
🔑 6. Bootloader (systemd-boot)
bash


Kopyala
bootctl install
/boot/loader/entries/arch.conf:

Kod


Kopyala
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/sda2 rw
🖥️ 7. GNOME Kurulumu
bash


Kopyala
pacman -S gnome gnome-extra gdm
systemctl enable gdm
systemctl enable NetworkManager
🚀 8. Çıkış ve Yeniden Başlat
bash


Kopyala
exit
umount -R /mnt
reboot
✨ Artık Arch Linux, systemd init sistemiyle GNOME masaüstü ortamında açılacak.

İstersen sana bu adımların görsel bir akış diyagramını da hazırlayabilirim; kurulum sürecini daha net görürsün. İstiyor musun?






Şunu dediniz:
Kullanıcı eklemedim
Copilot şunu dedi:
Doğru, kullanıcı eklemeden sistem açılırsa sadece root hesabın olur. Bu güvenlik açısından riskli, çünkü günlük kullanımda root ile çalışmak önerilmez. Hemen yeni bir kullanıcı oluşturup ona sudo yetkisi vermelisin. İşte adımlar:

👤 1. Yeni Kullanıcı Oluştur
Örnek: kullanıcı adı ali

bash


Kopyala
useradd -m -G wheel -s /bin/bash ali
passwd ali
-m → home dizini oluşturur (/home/ali)

-G wheel → sudo yetkisi için gerekli gruba ekler

-s /bin/bash → varsayılan shell olarak bash ayarlar

🔑 2. Sudo Yetkisi Ver
visudo ile sudoers dosyasını aç:

bash


Kopyala
EDITOR=nano visudo
Şu satırı aktif et:

Kod


Kopyala
%wheel ALL=(ALL:ALL) ALL
Kaydedip çık.

🚀 3. Root’tan Çıkış ve Kullanıcıya Geçiş
bash


Kopyala
exit
login ali
Artık GNOME’u bu kullanıcı ile açabilirsin. Root sadece sistem yönetimi için kullanılmalı.

👉 İstersen sana GNOME oturum açılışında otomatik olarak bu kullanıcıyla giriş yapmayı da gösterebilirim. İlgini çeker mi?






Şunu dediniz:
#!/bin/bash
set -euo pipefail

TITLE="Arch GNOME Installer"
LOGFILE="install.log"

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
  echo "Bu script root olarak çalıştırılmalıdır."
  exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
  echo "whiptail yüklü değil. 'pacman -Sy --noconfirm libnewt' ile yükleyin."
  exit 1
fi

if ! whiptail --title "$TITLE" --yesno "Kuruluma başlamak istiyor musunuz?" 10 60; then
  clear; echo "Kurulum iptal edildi."; exit 1
fi

umount -R /mnt 2>/dev/null || true
mkdir -p /mnt

(
echo 5; echo "Disk seçimi..."
DISKS=$(lsblk -dpno NAME | grep -E "/dev/sd|/dev/nvme|/dev/vda")
MENU_OPTS=()
for d in $DISKS; do MENU_OPTS+=("$d" "$(lsblk -dnpo SIZE "$d")"); done
DISK=$(whiptail --title "$TITLE" --menu "Hedef Disk Seçin (TÜM VERİLER SİLİNECEK):" 20 70 10 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

NEWUSER=$(whiptail --title "$TITLE" --inputbox "Yeni kullanıcı adı:" 10 60 3>&1 1>&2 2>&3)
USERPASS=$(whiptail --title "$TITLE" --passwordbox "Kullanıcı şifresi:" 10 60 3>&1 1>&2 2>&3)
ROOTPASS=$(whiptail --title "$TITLE" --passwordbox "Root şifresi:" 10 60 3>&1 1>&2 2>&3)

# Dinamik locale listesi
LOCALES=$(locale -a | grep UTF-8)
MENU_OPTS=()
for l in $LOCALES; do MENU_OPTS+=("$l" "$l"); done
LOCALE=$(whiptail --title "$TITLE" --menu "Dil/Locale Seçin:" 20 70 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

# Dinamik klavye listesi
KEYMAPS=$(localectl list-keymaps | head -n 200)
MENU_OPTS=()
for k in $KEYMAPS; do MENU_OPTS+=("$k" "$k"); done
KEYMAP=$(whiptail --title "$TITLE" --menu "Klavye Düzeni Seçin:" 20 70 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

# Dinamik timezone listesi
TIMEZONES=$(timedatectl list-timezones | head -n 200)
MENU_OPTS=()
for t in $TIMEZONES; do MENU_OPTS+=("$t" "$t"); done
TIMEZONE=$(whiptail --title "$TITLE" --menu "Zaman Dilimi Seçin:" 20 70 15 "${MENU_OPTS[@]}" 3>&1 1>&2 2>&3)

HOSTNAME=$(whiptail --title "$TITLE" --inputbox "Hostname (Bilgisayar adı):" 10 60 3>&1 1>&2 2>&3)

NETTYPE=$(whiptail --title "$TITLE" --menu "Ağ Tipi Seçin:" 20 70 10 \
"dhcp" "Otomatik (DHCP)" \
"static" "Statik IP" \
"wifi" "Kablosuz (Wi-Fi)" \
3>&1 1>&2 2>&3)

if [ "$NETTYPE" = "static" ]; then
  IPADDR=$(whiptail --title "$TITLE" --inputbox "IP Adresi:" 10 60 3>&1 1>&2 2>&3)
  NETMASK=$(whiptail --title "$TITLE" --inputbox "Ağ Maskesi:" 10 60 3>&1 1>&2 2>&3)
  GATEWAY=$(whiptail --title "$TITLE" --inputbox "Gateway:" 10 60 3>&1 1>&2 2>&3)
  DNS=$(whiptail --title "$TITLE" --inputbox "DNS:" 10 60 3>&1 1>&2 2>&3)
fi

if [ "$NETTYPE" = "wifi" ]; then
  SSID=$(whiptail --title "$TITLE" --inputbox "Wi-Fi SSID:" 10 60 3>&1 1>&2 2>&3)
  WIFIPASS=$(whiptail --title "$TITLE" --passwordbox "Wi-Fi Şifresi:" 10 60 3>&1 1>&2 2>&3)
fi

EXTRAPKGS=$(whiptail --title "$TITLE" --checklist "Ek paketleri seçin:" 20 70 10 \
"firefox" "Web tarayıcı (Firefox)" ON \
"chromium" "Web tarayıcı (Chromium)" OFF \
"libreoffice-fresh" "Ofis paketi" ON \
"vlc" "Medya oynatıcı" ON \
"gimp" "Resim düzenleyici" OFF \
"cups" "Yazıcı desteği" OFF \
"base-devel" "Derleme araçları" ON \
"flatpak" "Flatpak desteği" OFF \
"pipewire" "Ses sistemi" ON \
3>&1 1>&2 2>&3)
EXTRAPKGS=$(echo $EXTRAPKGS | sed 's/"//g')

echo 15; echo "Disk bölümlendirme..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary 512MiB 100%

BOOTPART=$(ls "${DISK}"* | grep -E "${DISK}p?1$")
ROOTPART=$(ls "${DISK}"* | grep -E "${DISK}p?2$")

mkfs.fat -F32 "$BOOTPART"
mkfs.ext4 -F "$ROOTPART"

echo 25; echo "Disk mount ediliyor..."
mount "$ROOTPART" /mnt
mkdir -p /mnt/boot
mount "$BOOTPART" /mnt/boot

echo 40; echo "Mirror listesi güncelleniyor..."
pacman -Sy --noconfirm

# GNOME paketleri
DESKTOP_PKGS="gnome gdm"
DM_ENABLE="systemctl enable gdm"

echo 55; echo "Temel sistem kuruluyor..."
pacstrap /mnt base linux linux-firmware $DESKTOP_PKGS $EXTRAPKGS nano sudo vim git unzip plymouth systemd networkmanager network-manager-applet

echo 70; echo "fstab oluşturuluyor..."
genfstab -U /mnt >> /mnt/etc/fstab

echo 85; echo "Chroot işlemleri..."
arch-chroot /mnt bash -c "
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

if [[ "${NETTYPE}" == "wifi" ]]; then
  systemctl enable NetworkManager
  nmcli dev wifi connect "${SSID}" password "${WIFIPASS}" || true
fi

# GNOME için display manager
${DM_ENABLE}

# Sudo ve kullanıcı
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
useradd -m -G wheel -s /bin/bash ${NEWUSER}
echo "${NEWUSER}:${USERPASS}" | chpasswd
echo "root:${ROOTPASS}" | chpasswd
"

echo 100; echo "Kurulum tamamlandı!"
) | whiptail --gauge "Kurulum devam ediyor, lütfen bekleyin..." 20 70 0

umount -R /mnt
whiptail --title "$TITLE" --msgbox "Kurulum tamamlandı! Arch Linux GNOME hazır.\nLog: $LOGFILE" 10 70
clear

if whiptail --yesno "Sistemi yeniden başlatmak ister misiniz?" 10 60; then
  reboot
fi 
