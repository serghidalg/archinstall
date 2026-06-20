#!/usr/bin/env bash
#
# 04-post-install.sh
# Se ejecuta como USUARIO NORMAL (no root), después de reiniciar tras
# 03-chroot-config.sh. Instala Hyprland y todo el entorno, y despliega
# los dotfiles de la carpeta config/ de este mismo repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: no corras este script como root. Hazlo con tu usuario normal."
    exit 1
fi

echo "=================================================================="
echo "  Instalando Hyprland + entorno de escritorio"
echo "=================================================================="

# ---- Paquetes oficiales ----
sudo pacman -S --needed --noconfirm \
    hyprland waybar kitty rofi thunar dunst \
    hyprpaper hyprlock hypridle grim slurp wl-clipboard \
    qt5ct qt6ct polkit-kde-agent \
    pipewire pipewire-pulse wireplumber pavucontrol \
    network-manager-applet brightnessctl \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    btop papirus-icon-theme \
    sddm firefox

# ---- Display manager ----
sudo systemctl enable sddm

# ---- AUR helper (yay), si no existe ----
if ! command -v yay &> /dev/null; then
    echo "--> Instalando yay (AUR helper)..."
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

# ---- Paquetes AUR ----
yay -S --needed --noconfirm wlogout

# ---- Despliegue de dotfiles ----
echo "--> Copiando configuraciones a ~/.config/..."
mkdir -p ~/.config
cp -r "$SCRIPT_DIR/config/hypr"     ~/.config/
cp -r "$SCRIPT_DIR/config/waybar"   ~/.config/
cp -r "$SCRIPT_DIR/config/rofi"     ~/.config/
cp -r "$SCRIPT_DIR/config/wlogout"  ~/.config/
cp -r "$SCRIPT_DIR/config/dunst"    ~/.config/
cp -r "$SCRIPT_DIR/config/kitty"    ~/.config/

mkdir -p ~/Pictures/wallpapers
echo
echo "NOTA: no olvides poner tu wallpaper en ~/Pictures/wallpapers/fondo.jpg"
echo "      (referenciado en ~/.config/hypr/hyprpaper.conf)"

# btop.conf se autogenera la primera vez que se abre; lo generamos ahora
# en modo no interactivo para poder aplicar los overrides:
mkdir -p ~/.config/btop
timeout 1 btop --config ~/.config/btop/btop.conf || true
if [ -f ~/.config/btop/btop.conf ]; then
    cat "$SCRIPT_DIR/config/btop/btop-overrides.conf" >> ~/.config/btop/btop.conf
fi

echo
echo "=================================================================="
echo "  Instalación completa."
echo "  Reinicia: sudo reboot"
echo "  En la pantalla de SDDM, elige la sesión 'Hyprland'."
echo
echo "  Recuerda copiar tu wallpaper a ~/Pictures/wallpapers/fondo.jpg"
echo "  y revisar hyprpaper.conf si el nombre de tu monitor no es eDP-1"
echo "  (compruébalo con: hyprctl monitors, una vez dentro de Hyprland)."
echo "=================================================================="
