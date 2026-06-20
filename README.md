# dotfiles

Arch Linux + Hyprland, instalación desde cero. Disco cifrado con LUKS2
(desbloqueo por TPM2 con passphrase de respaldo), Btrfs con subvolúmenes
y snapshots automáticos vía snapper, SDDM como display manager, waybar +
rofi + wlogout + dunst con la misma paleta, hypridle/hyprlock para
bloqueo automático.

Pensado para teclado Dvorak: los binds de `hyprland.conf` usan códigos
físicos de tecla en vez de keysyms, así que no dependen del layout activo.

## Estructura

```
.
├── 01-partition.sh       # particionado + Btrfs (desde el ISO live)
├── 02-bootstrap.sh       # pacstrap + fstab (desde el ISO live)
├── 03-chroot-config.sh   # locale, usuario, GRUB+tema, dotfiles, SDDM, snapper (en chroot)
├── 04-post-install.sh    # solo yay + wlogout (AUR, usuario normal post-reboot)
├── snap-now.sh           # snapshot manual rápido
└── config/
    ├── hypr/       hyprland.conf, hypridle.conf, hyprlock.conf, hyprpaper.conf
    ├── waybar/     config.jsonc, style.css
    ├── rofi/       config.rasi
    ├── wlogout/    layout.json, style.css
    ├── dunst/      dunstrc
    ├── kitty/      kitty.conf
    └── btop/       btop-overrides.conf
```

## Instalación

Desde el ISO de Arch, con red ya configurada:

```bash
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

**En este punto, todo ya está funcionando**: SDDM, Hyprland, waybar,
rofi, dunst, hypridle/hyprlock, kitty, btop y los dotfiles, ya instalados
y configurados desde dentro del chroot. Inicia sesión en SDDM y elige
**Hyprland**.

Lo único pendiente es `wlogout` (viene de AUR — `makepkg` no compila
como root, necesita tu usuario normal real, no el chroot):

```bash
cd ~/arch-hyprland-dotfiles
./04-post-install.sh
```

`01-partition.sh` borra el disco que se le indique. Pide el nombre dos
veces y confirmación explícita; aun así, revisa con `lsblk` antes de
correrlo.

## Cifrado de disco

La partición raíz (todo excepto `/boot`, que va sin cifrar en la ESP)
está cifrada con **LUKS2**. Desbloqueo:

- **TPM2 automático** (si tu hardware lo tiene): arranca directo, sin
  pedir nada — `01-partition.sh` te pide la passphrase de todos modos
  (es la base del cifrado), pero `03-chroot-config.sh` enrola el TPM2
  al final para que no tengas que escribirla en cada arranque normal.
- **Passphrase de respaldo**: siempre activa. Si el TPM2 falla, está
  ausente, o detecta manipulación del arranque (firmware/bootloader
  modificados), simplemente te la pide — nunca te quedas sin acceso.

**Guarda la passphrase en un sitio seguro.** Sin ella no hay
recuperación posible, ni con TPM2 ni de ninguna otra forma.

Para desactivar el TPM2 más adelante y volver a pedir solo passphrase:
```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/<partición_root>
```

Para entrar al sistema desde el ISO live (por ejemplo, para un
`snapper rollback` de emergencia), hay que desbloquear el LUKS primero:
```bash
cryptsetup open /dev/<partición_root> cryptroot
mount -o subvol=@ /dev/mapper/cryptroot /mnt
# ...resto del montaje habitual (boot, home, etc.) antes de chroot
```

## Particionado

GPT con EFI (512M, FAT32) + Btrfs en el resto, con subvolúmenes:

| Subvolumen   | Punto de montaje              |
|--------------|--------------------------------|
| `@`          | `/`                            |
| `@home`      | `/home`                        |
| `@snapshots` | `/.snapshots`                  |
| `@var_log`   | `/var/log`                     |
| `@pkg`       | `/var/cache/pacman/pkg`        |

Montados con `compress=zstd,noatime`.

## Snapshots

Snapper queda activo sobre `@` con timeline automático (limpieza
configurada) y `snap-pac` para snapshot pre/post en cada operación de
pacman.

```bash
sudo snapper -c root list
sudo snapper -c root create --description "..."   # o: ./snap-now.sh "..."
sudo snapper -c root undochange <N>..0
```

`/home` está en un subvolumen separado, sin snapshots configurados por
defecto (se puede añadir con `snapper -c home create-config /home`).

## Paquetes principales

hyprland, waybar, kitty, rofi, thunar, dunst, hyprpaper, hyprlock,
hypridle, grim/slurp, pipewire, sddm, firefox. `wlogout` se instala vía
AUR con `yay` (el script lo bootstrapea si no existe).

## Bootloader

GRUB (no systemd-boot), replicando tu `/etc/default/grub` actual:
timeout 5, GFX 2560x1440, sin recovery entries, con el tema
**Particle-window** (de [yeyushengfan258/Particle-grub-theme](https://github.com/yeyushengfan258/Particle-grub-theme),
variante `2k`, instalado en `/usr/share/grub/themes/`). `os-prober` queda
habilitado en la config por si en el futuro agregas otro sistema, aunque
no se instala el paquete `os-prober` por defecto — añádelo a mano
(`pacman -S os-prober`) si lo necesitas.

## Pendiente / a mano tras instalar

- Wallpaper en `~/Pictures/wallpapers/fondo.jpg` (referenciado en
  `hyprpaper.conf`, configurado para el monitor `eDP-1` — ajustar si
  el nombre del monitor es otro, ver `hyprctl monitors`). La carpeta
  ya existe, solo falta el archivo.
- `wlogout` (AUR) — correr `./04-post-install.sh` como usuario normal.

## Licencia

MIT, o lo que sea, son dotfiles.
