#!/usr/bin/env bash
#
# 04-post-install.sh
# Se ejecuta como USUARIO NORMAL (no root), tras el primer arranque.
#
# Todo lo "oficial" (Hyprland, waybar, SDDM, dotfiles...) ya quedó
# instalado y configurado desde 03-chroot-config.sh. Lo único que
# falta es esto: wlogout viene de AUR, y makepkg se niega a compilar
# como root, así que necesita un usuario normal de verdad (con systemd
# y red ya en marcha, no en un chroot).

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: no corras este script como root. Hazlo con tu usuario normal."
    exit 1
fi

echo "=================================================================="
echo "  Instalando yay (AUR helper) + wlogout"
echo "=================================================================="

if ! command -v yay &> /dev/null; then
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

yay -S --needed --noconfirm wlogout librewolf-bin

echo
echo "=================================================================="
echo "  Aplicando preferencia de modo oscuro (dconf)"
echo "=================================================================="
# Esto necesita un bus de sesión real corriendo, por eso no se puede
# hacer dentro del chroot en 03-chroot-config.sh.
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"

echo
echo "=================================================================="
echo "  Listo. No olvides poner tu wallpaper en:"
echo "    ~/Pictures/wallpapers/fondo.jpg"
echo "  (la carpeta ya existe, solo falta el archivo)"
echo
echo "  Si el nombre de tu monitor no es eDP-1, ajusta:"
echo "    ~/.config/hypr/hyprpaper.conf"
echo "  (lo ves con: hyprctl monitors)"
echo "=================================================================="
