#!/bin/bash
[ -n "$DISPLAY" ] && echo "Must run from tty cli" && exit 1

# Check if executed as root
[ "$EUID" -ne 0 ] && echo "Run as root with:  sudo $0" && exit 1

# Copy files
cp ./src/watermark.png /usr/share/plymouth/themes/arch-os/
cp ./src/arch-os.plymouth /usr/share/plymouth/themes/arch-os/

# Start plymouth daemon
plymouthd

# A) Test system upgrade
plymouth change-mode --system-upgrade
plymouth --show-splash

# B) Test password promt
# plymouth --show-splash
# plymouth ask-for-password

# Sleep for 8 seconds
sleep 8

# Quit
plymouth quit
