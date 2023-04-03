#!/usr/bin/env bash
set -Eeuo pipefail

# Check if executed as root
[ "$EUID" -ne 0 ] && echo "Run as root with: sudo $0" && exit 1

# Remove old arch-elegant
[ -d /usr/share/plymouth/themes/arch-elegant ] && rm -rf /usr/share/plymouth/themes/arch-elegant

# Copy new arch-elegant
cp -r ./arch-elegant/ /usr/share/plymouth/themes/arch-elegant

# Set theme and rebuild
plymouth-set-default-theme -R arch-elegant
