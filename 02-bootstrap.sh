#!/usr/bin/env bash
#
# 02-bootstrap.sh
# Se ejecuta DESDE EL ISO LIVE, justo después de 01-partition.sh
# (con todo ya montado en /mnt).
#
# Instala el sistema base con pacstrap y genera el fstab.

set -euo pipefail

if ! mountpoint -q /mnt; then
    echo "ERROR: /mnt no está montado. Corre primero 01-partition.sh"
    exit 1
fi

echo "--> Sincronizando reloj..."
timedatectl set-ntp true

echo "--> Instalando sistema base (esto tarda varios minutos)..."
pacstrap -K /mnt \
    base base-devel linux linux-firmware \
    btrfs-progs \
    networkmanager \
    sudo vim git \
    snapper snap-pac \
    intel-ucode amd-ucode

echo "--> Generando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo
echo "fstab generado:"
cat /mnt/etc/fstab

echo
echo "--> Copiando dotfiles y scripts dentro del nuevo sistema..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR" /mnt/root/arch-hyprland-dotfiles

echo
echo "=================================================================="
echo "  Sistema base instalado."
echo "  Siguiente paso:"
echo "    arch-chroot /mnt"
echo "    cd /root/arch-hyprland-dotfiles"
echo "    ./03-chroot-config.sh"
echo "=================================================================="
