#!/usr/bin/env bash
#
# 03-chroot-config.sh
# Se ejecuta DENTRO de arch-chroot (después de 02-bootstrap.sh).
# Asume arranque UEFI (no BIOS legacy).

set -euo pipefail

echo "=================================================================="
echo "  Configuración del sistema (dentro del chroot)"
echo "=================================================================="

# ---- Zona horaria ----
read -rp "Zona horaria (ej: Europe/Madrid): " TZ_REGION
ln -sf "/usr/share/zoneinfo/${TZ_REGION}" /etc/localtime
hwclock --systohc

# ---- Locale ----
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=es_ES.UTF-8" > /etc/locale.conf

# ---- Hostname ----
read -rp "Hostname para este equipo: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# ---- Teclado en consola (vconsole, solo para la TTY de instalación) ----
# Tu Dvorak ya está configurado aparte dentro de hyprland.conf, esto es
# solo para la consola de texto antes de entrar a Hyprland.
echo "KEYMAP=us" > /etc/vconsole.conf

# ---- Contraseña de root ----
echo "Establece la contraseña de root:"
passwd

# ---- Usuario normal ----
read -rp "Nombre de usuario a crear: " USERNAME
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Establece la contraseña de $USERNAME:"
passwd "$USERNAME"

# Habilitar sudo para el grupo wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Mover los dotfiles/scripts de root a la home del usuario nuevo
if [ -d /root/arch-hyprland-dotfiles ]; then
    cp -r /root/arch-hyprland-dotfiles "/home/${USERNAME}/arch-hyprland-dotfiles"
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/arch-hyprland-dotfiles"
fi

# ---- Bootloader (systemd-boot, asume UEFI) ----
bootctl install

ROOT_UUID=$(findmnt -no UUID /)

cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rootflags=subvol=@ rw
EOF

# ---- Servicios ----
systemctl enable NetworkManager
systemctl enable fstrim.timer

# ---- Snapper: snapshots automáticos del subvolumen raíz ----
# Esto es justo la red de seguridad que te habría salvado del "find -delete":
# con snap-pac, cada "pacman -S/-R" crea un snapshot automático antes/después,
# y puedes además tomar snapshots manuales en cualquier momento.
umount /.snapshots
rm -rf /.snapshots
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -a
snapper -c root set-config "TIMELINE_CREATE=yes"
snapper -c root set-config "TIMELINE_CLEANUP=yes"
snapper -c root set-config "TIMELINE_LIMIT_HOURLY=6"
snapper -c root set-config "TIMELINE_LIMIT_DAILY=7"
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

echo
echo "=================================================================="
echo "  Configuración base completa."
echo "  Sal del chroot (exit), desmonta y reinicia:"
echo "    exit"
echo "    umount -R /mnt"
echo "    reboot"
echo
echo "  Tras reiniciar y entrar con tu usuario ($USERNAME), corre:"
echo "    cd ~/arch-hyprland-dotfiles   (o donde hayas copiado la carpeta)"
echo "    ./04-post-install.sh"
echo "=================================================================="
