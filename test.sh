#!/bin/bash
[ -n "$DISPLAY" ] && echo "Must run from tty cli" && exit 1

# Copy files
sudo cp ./arch-elegant/watermark.png /usr/share/plymouth/themes/arch-elegant/
sudo cp ./arch-elegant/arch-elegant.plymouth /usr/share/plymouth/themes/arch-elegant/

# Start plymouth daemon
sudo plymouthd

# A) Test system upgrade
sudo plymouth change-mode --system-upgrade
sudo plymouth --show-splash

# B) Test password promt
#sudo plymouth --show-splash
#sudo plymouth ask-for-password

# Sleep for 8 seconds
sleep 8

# Quit
sudo plymouth quit
