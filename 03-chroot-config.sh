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

# ---- Bootloader: GRUB (réplica de tu configuración actual, asume UEFI) ----
# grub y efibootmgr ya vienen instalados desde el pacstrap (02-bootstrap.sh)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Tu /etc/default/grub, tal cual lo tenías
cat > /etc/default/grub << 'GRUBEOF'
# GRUB boot loader configuration
GRUB_DEFAULT="0"
GRUB_TIMEOUT="5"
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
GRUB_CMDLINE_LINUX=""

# Preload both GPT and MBR modules so that they are not missed
GRUB_PRELOAD_MODULES="part_gpt part_msdos"

# Uncomment to enable booting from LUKS encrypted devices
#GRUB_ENABLE_CRYPTODISK="y"

# Set to 'countdown' or 'hidden' to change timeout behavior,
# press ESC key to display menu.
GRUB_TIMEOUT_STYLE="menu"

# Uncomment to use basic console
GRUB_TERMINAL_INPUT="console"

# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console

# The resolution used on graphical terminal
GRUB_GFXMODE=2560x1440,auto

# Uncomment to allow the kernel use the same resolution used by grub
GRUB_GFXPAYLOAD_LINUX="keep"

#GRUB_DISABLE_LINUX_UUID="true"

# Uncomment to disable generation of recovery mode menu entries
GRUB_DISABLE_RECOVERY="true"

# Colores del menú
export GRUB_COLOR_NORMAL="light-blue/black"
export GRUB_COLOR_HIGHLIGHT="light-cyan/blue"

# Tema Particle-window
GRUB_BACKGROUND="/usr/share/grub/themes/Particle-window/background.jpg"
GRUB_THEME="/usr/share/grub/themes/Particle-window/theme.txt"

#GRUB_INIT_TUNE="480 440 1"
#GRUB_SAVEDEFAULT="true"
#GRUB_DISABLE_SUBMENU="y"

# Sin dual-boot, no necesitamos os-prober, pero lo dejamos igual que
# tenías por si en el futuro añades otro sistema:
GRUB_DISABLE_OS_PROBER="false"
GRUBEOF

# ---- Tema Particle-window (yeyushengfan258/Particle-grub-theme) ----
# Instalado SIN el flag -b, para que quede en /usr/share/grub/themes/
# (coincide con las rutas de GRUB_BACKGROUND/GRUB_THEME de arriba).
# -s 2k porque tu GRUB_GFXMODE es 2560x1440.
git clone https://github.com/yeyushengfan258/Particle-grub-theme.git /tmp/particle-theme
(cd /tmp/particle-theme && ./install.sh -t window -s 2k)
rm -rf /tmp/particle-theme

grub-mkconfig -o /boot/grub/grub.cfg

# ---- Desplegar dotfiles (waybar, rofi, hypr*, wlogout, dunst, kitty, btop) ----
DOTFILES_DIR="/home/${USERNAME}/arch-hyprland-dotfiles"
USER_CONFIG="/home/${USERNAME}/.config"
mkdir -p "$USER_CONFIG"
cp -r "$DOTFILES_DIR/config/hypr"    "$USER_CONFIG/"
cp -r "$DOTFILES_DIR/config/waybar"  "$USER_CONFIG/"
cp -r "$DOTFILES_DIR/config/rofi"    "$USER_CONFIG/"
cp -r "$DOTFILES_DIR/config/wlogout" "$USER_CONFIG/"
cp -r "$DOTFILES_DIR/config/dunst"   "$USER_CONFIG/"
cp -r "$DOTFILES_DIR/config/kitty"   "$USER_CONFIG/"
mkdir -p "$USER_CONFIG/btop"
cp "$DOTFILES_DIR/config/btop/btop.conf" "$USER_CONFIG/btop/btop.conf"
mkdir -p "/home/${USERNAME}/Pictures/wallpapers"
chown -R "${USERNAME}:${USERNAME}" "$USER_CONFIG" "/home/${USERNAME}/Pictures"

# ---- Display manager ----
systemctl enable sddm

# ---- Servicios ----
systemctl enable NetworkManager
systemctl enable fstrim.timer

# ---- Snapper: snapshots automáticos del subvolumen raíz ----
# snap-pac crea un snapshot antes/después de cada operación de pacman,
# y se pueden tomar snapshots manuales en cualquier momento.
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
echo "  Configuración completa. Hyprland, SDDM y todos los dotfiles ya"
echo "  están listos para el primer arranque."
echo
echo "  Sal del chroot, desmonta y reinicia:"
echo "    exit"
echo "    umount -R /mnt"
echo "    reboot"
echo
echo "  Tras reiniciar, inicia sesión gráfica en SDDM con tu usuario"
echo "  ($USERNAME) y elige la sesión Hyprland. Todo debería funcionar"
echo "  YA, salvo wlogout (viene de AUR, requiere usuario normal real"
echo "  para compilar) — corre ./04-post-install.sh una vez dentro para"
echo "  completar eso."
echo "=================================================================="
