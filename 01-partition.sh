#!/usr/bin/env bash
#
# 01-partition.sh
# Se ejecuta DESDE EL ISO LIVE DE ARCH (antes de instalar nada).
#
# Particiona el disco con tabla GPT:
#   - Partición EFI (512 MiB, FAT32)
#   - Partición raíz Btrfs (resto del disco) con subvolúmenes:
#       @         -> /
#       @home     -> /home
#       @snapshots-> /.snapshots   (usado por snapper)
#       @var_log  -> /var/log
#       @pkg      -> /var/cache/pacman/pkg
#
# El esquema de subvolúmenes + snapper es justo lo que te habría salvado
# del incidente con "find -delete": con snapshots automáticos puedes
# volver atrás en segundos a un estado de hace minutos/horas.
#
# ESTE SCRIPT BORRA TODO EL CONTENIDO DEL DISCO QUE INDIQUES.
# No hay deshacer. Léelo dos veces antes de ejecutarlo.

set -euo pipefail

echo "=================================================================="
echo "  ADVERTENCIA: este script BORRA POR COMPLETO el disco indicado."
echo "=================================================================="
echo

lsblk -d -o NAME,SIZE,MODEL,TYPE
echo
read -rp "Escribe el nombre EXACTO del disco a usar (ej: sda, nvme0n1, NO /dev/sda): " DISKNAME
DISK="/dev/${DISKNAME}"

if [ ! -b "$DISK" ]; then
    echo "ERROR: $DISK no existe o no es un dispositivo de bloques. Abortando."
    exit 1
fi

echo
echo "Vas a borrar POR COMPLETO: $DISK"
lsblk "$DISK"
echo
read -rp "Escribe exactamente la palabra BORRAR (mayúsculas) para confirmar: " CONFIRM1
if [ "$CONFIRM1" != "BORRAR" ]; then
    echo "Cancelado. No se ha tocado el disco."
    exit 1
fi
read -rp "Última confirmación. Escribe de nuevo el nombre del disco ($DISKNAME) para continuar: " CONFIRM2
if [ "$CONFIRM2" != "$DISKNAME" ]; then
    echo "Cancelado. No se ha tocado el disco."
    exit 1
fi

echo
echo "--> Particionando $DISK (GPT: EFI 512MiB + resto en Btrfs)..."

# Determinar nombres de partición correctos (nvme usa "p1", sata/virtio usa "1")
if [[ "$DISKNAME" == nvme* ]] || [[ "$DISKNAME" == mmcblk* ]]; then
    PART_EFI="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_EFI="${DISK}1"
    PART_ROOT="${DISK}2"
fi

parted -s "$DISK" \
    mklabel gpt \
    mkpart "EFI" fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart "ROOT" btrfs 513MiB 100%

echo "--> Formateando partición EFI ($PART_EFI)..."
mkfs.fat -F32 -n EFI "$PART_EFI"

echo "--> Formateando partición raíz Btrfs ($PART_ROOT)..."
mkfs.btrfs -f -L ROOT "$PART_ROOT"

echo "--> Creando subvolúmenes Btrfs..."
mount "$PART_ROOT" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@pkg
umount /mnt

echo "--> Montando subvolúmenes con compresión zstd + noatime..."
MOUNT_OPTS="noatime,compress=zstd,space_cache=v2"

mount -o "$MOUNT_OPTS,subvol=@" "$PART_ROOT" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache/pacman/pkg}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART_ROOT" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART_ROOT" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@var_log" "$PART_ROOT" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@pkg" "$PART_ROOT" /mnt/var/cache/pacman/pkg
mount "$PART_EFI" /mnt/boot

echo
echo "=================================================================="
echo "  Particionado y montaje completos."
echo "  Partición EFI : $PART_EFI  -> /mnt/boot"
echo "  Partición ROOT: $PART_ROOT -> /mnt (subvolúmenes @ @home @snapshots @var_log @pkg)"
echo
echo "  Siguiente paso: ./02-bootstrap.sh"
echo "=================================================================="
