<div align="center">
    <h1>plymouth-theme-arch-os</h1>
    <p>Used by <a href="https://github.com/murkl/arch-os">Arch OS</a></p>
    <p><img src="./screenshot.png" /></p>
    <p><b>Arch OS Bootsplash Theme for Plymouth</b></p>
    <p>
      <img src="https://img.shields.io/badge/MAINTAINED-YES-green?style=for-the-badge">
      <img src="https://img.shields.io/badge/License-GPL_v2-blue?style=for-the-badge">
    </p>
</div>

## Install Plymouth

Follow the [Arch Wiki](https://wiki.archlinux.org/title/Plymouth) ...

## Install Theme (Arch/AUR)

Arch AUR: [plymouth-theme-arch-os](https://aur.archlinux.org/packages/plymouth-theme-arch-os)

## Install Theme (manual)

```
# Install dependencies
sudo pacman -S git cantarell-fonts

# Clone repo
git clone https://github.com/murkl/plymouth-theme-arch-os.git

# Change dir
cd plymouth-theme-arch-os

# Add to plymouth themes dir
sudo cp -r ./src /usr/share/plymouth/themes/arch-os

# Set as default theme and rebuild
sudo plymouth-set-default-theme -R arch-os
```

## Remove Theme

```
# Arch/AUR
sudo pacman -R plymouth-theme-arch-os

# Manual
sudo rm -r /usr/share/plymouth/themes/arch-os

# Revert default theme
sudo plymouth-set-default-theme --reset
```

## Image Information

### Size

- Watermark size: `150x150`
- Total entry size: `340x34`
- Lock size: `8x34`
- Entry size: `332x34`

### Color

- Background: `#2e3440ff`
- Foreground light: `#eeedecff`
- Foreground dark: `#4c566aff`

## Sources

Spinner Repository: [Link](https://gitlab.freedesktop.org/plymouth/plymouth/-/tree/main/themes/spinner)
