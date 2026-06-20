# Arch + Hyprland — instalación desde cero

Esto instala Arch Linux desde un ISO live, con Btrfs + snapshots automáticos
(snapper), y deja configurado Hyprland con todo lo que armamos: waybar, rofi,
wlogout, dunst, hypridle/hyprlock, kitty con paleta "techy", y atajos
adaptados a teclado Dvorak por posición física.

## Orden de ejecución

| # | Script | Dónde se ejecuta | Qué hace |
|---|--------|-------------------|----------|
| 1 | `01-partition.sh` | ISO live de Arch | Particiona y formatea el disco (Btrfs + subvolúmenes) |
| 2 | `02-bootstrap.sh` | ISO live de Arch | Instala el sistema base (pacstrap) + fstab |
| 3 | `03-chroot-config.sh` | Dentro de `arch-chroot /mnt` | Timezone, locale, usuario, bootloader, snapper |
| 4 | `04-post-install.sh` | Ya arrancado, como usuario normal | Hyprland + dotfiles |

### Paso a paso

```bash
# 1. Arranca desde el ISO de Arch, conecta a internet (iwctl si es wifi)
# 2. Copia esta carpeta al ISO live (USB, curl, scp, lo que tengas a mano)
cd arch-hyprland-dotfiles
chmod +x *.sh

./01-partition.sh
./02-bootstrap.sh

arch-chroot /mnt
cd /root/arch-hyprland-dotfiles
chmod +x *.sh
./03-chroot-config.sh

exit
umount -R /mnt
reboot
```

Tras reiniciar, entra con el usuario que creaste (consola de texto, sin
entorno gráfico todavía):

```bash
cd ~/arch-hyprland-dotfiles
chmod +x *.sh
./04-post-install.sh
sudo reboot
```

En la pantalla de **SDDM**, elige la sesión **Hyprland**.

## ⚠️ Sobre `01-partition.sh`

Este script **borra por completo** el disco que indiques. Pide el nombre
del disco dos veces y una palabra de confirmación exacta — aun así, lee el
script antes de correrlo y confirma con `lsblk` que el disco que vas a
indicar es el correcto (no un USB, no un disco con otros datos).

## Tu red de seguridad: snapshots con Snapper

Esto es justo lo que te habría salvado del incidente con `find -delete`.
El subvolumen raíz (`@`) tiene snapshots automáticos:

- Cada vez que instalas/quitas un paquete con `pacman` (gracias a `snap-pac`).
- Cada hora (timeline), limpiándose solas según la política configurada.

**Ver snapshots disponibles:**
```bash
sudo snapper -c root list
```

**Tomar un snapshot manual antes de algo arriesgado** (usa el helper incluido):
```bash
./snap-now.sh "antes de probar tal cosa"
```

**Restaurar un snapshot** (vuelve TODO el sistema, incluyendo archivos
personales en `/`, al estado de ese snapshot):
```bash
sudo snapper -c root list                  # busca el número que quieres
sudo snapper -c root undochange <N>..0     # revierte cambios desde el snapshot N hasta ahora
```
o, para una restauración completa offline (más seguro para cambios grandes),
arranca desde el ISO live y usa `snapper -c root rollback <N>`.

> Nota: `/home` está en su propio subvolumen (`@home`) separado de `@`.
> Esto es intencional — significa que los snapshots de `@` (el sistema)
> son rápidos y frecuentes, pero si quieres que tus archivos personales
> en `/home` también tengan snapshots, hay que configurar snapper aparte
> para ese subvolumen (`snapper -c home create-config /home`). Pregúntame
> si quieres que te lo prepare también.

## Notas

- **Teclado Dvorak:** los atajos de `hyprland.conf` usan códigos físicos
  de tecla (`code:`), así que funcionan igual sin importar el layout
  activo. El layout de texto está puesto en `us` + `dvorak`.
- **Wallpaper:** copia tu imagen a `~/Pictures/wallpapers/fondo.jpg`
  después de la instalación. `hyprpaper.conf` está configurado para el
  monitor `eDP-1` — si tu monitor se llama distinto, ajústalo (lo ves con
  `hyprctl monitors`).
- **wlogout** se instala desde AUR vía `yay` (no está en repos oficiales).
- **btop**: ya viene con `confirm_exit = False` y `show_battery = False`
  aplicados automáticamente por el script 4.
- El popup de "¿cerrar ventana?" en **kitty** con procesos corriendo
  (como btop) está desactivado en su config.

## Estructura de este repo

```
arch-hyprland-dotfiles/
├── 01-partition.sh
├── 02-bootstrap.sh
├── 03-chroot-config.sh
├── 04-post-install.sh
├── snap-now.sh
├── README.md
└── config/
    ├── hypr/      (hyprland.conf, hypridle.conf, hyprlock.conf, hyprpaper.conf)
    ├── waybar/    (config.jsonc, style.css)
    ├── rofi/      (config.rasi)
    ├── wlogout/   (layout.json, style.css)
    ├── dunst/     (dunstrc)
    ├── kitty/     (kitty.conf)
    └── btop/      (btop-overrides.conf)
```
