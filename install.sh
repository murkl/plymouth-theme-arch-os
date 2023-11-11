#!/usr/bin/env bash
set -Eeuo pipefail

# Check if executed as root
[ "$EUID" -ne 0 ] && echo "Run as root with: sudo $0" && exit 1

# Remove old arch-os
[ -d /usr/share/plymouth/themes/arch-os ] && rm -rf /usr/share/plymouth/themes/arch-os

# Copy new arch-os
cp -r ./src /usr/share/plymouth/themes/arch-os

# Set theme and rebuild
plymouth-set-default-theme -R arch-os
