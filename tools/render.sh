#!/usr/bin/env bash
# Draws the splash with Plymouth on a virtual screen and saves each state once the
# logo or the field stands where two-step puts it. Installs the theme, so it runs
# as root in a throwaway Arch system.
# Usage: render.sh <folder>
set -euo pipefail

out="$(mkdir -p "$1" && cd "$1" && pwd)"
cd "$(dirname "$0")/.."

WIDTH=1280
HEIGHT=800
PNG=(-strip -define 'png:exclude-chunks=date,time')

key() { sed -n "s/^$1=//p" src/arch-os.plymouth; }
color() { echo "#$(key "$1" | cut -c3-8)"; }
background="$(color BackgroundStartColor)"

work="$(mktemp -d)"
cleanup() {
    plymouth quit 2>/dev/null || true
    kill "$xvfb" 2>/dev/null || true
    rm -rf "$work"
}
xvfb="" daemon=""
trap cleanup EXIT

# Fails with the end of the log, which plymouthd writes out as it quits.
fail() {
    echo "render: $1" >&2
    plymouth quit 2>/dev/null || true
    wait "$daemon" 2>/dev/null || true
    tail -n 30 "${out}/plymouthd.log" >&2 || true
    exit 1
}

rm -rf /usr/share/plymouth/themes/arch-os
cp -rT src /usr/share/plymouth/themes/arch-os
plymouth-set-default-theme arch-os
echo 'KEYMAP=us' >/etc/vconsole.conf

Xvfb :99 -screen 0 "${WIDTH}x${HEIGHT}x24" -nolisten tcp 2>/dev/null &
xvfb=$!
export DISPLAY=:99

# Saves the screen to a file once it shows an image at x,y, for at most ten seconds.
# Usage: shot <file> <image> <x> <y>
shot() {
    local i size
    size="$(magick identify -format '%wx%h' "$2")"
    for ((i = 0; i < 50; i++)); do
        if xwd -root -silent 2>/dev/null | magick xwd:- "${PNG[@]}" "PNG24:$1" 2>/dev/null &&
            magick "$1" -crop "${size}+$3+$4" +repage png:- |
            magick compare -metric AE -fuzz 2% png:- "$2" null: 2>/dev/null; then
            return 0
        fi
        sleep 0.2
    done
    fail "${2##*/} is not at +$3+$4 in ${1##*/}"
}

# Where two-step puts an image: screen * alignment - image * alignment, truncated.
place() { awk -v s="$1" -v i="$2" -v a="$3" 'BEGIN { print int(s * a - i * a) }'; }

magick src/watermark.png -background "$background" -alpha remove -alpha off "${work}/logo.png"
magick src/lock.png src/entry.png +append -background "$background" -alpha remove -alpha off "${work}/field.png"
# The bar of an update at PROGRESS percent, filled as two-step fills it.
PROGRESS=42
bar_w="$(key ProgressBarWidth)"
bar_h="$(key ProgressBarHeight)"
fill="$((bar_w * PROGRESS / 100))"
magick -size "${fill}x${bar_h}" "xc:$(color ProgressBarForegroundColor)" \
    -size "$((bar_w - fill))x${bar_h}" "xc:$(color ProgressBarBackgroundColor)" +append "${work}/bar.png"
read -r logo_w logo_h < <(magick identify -format '%w %h\n' "${work}/logo.png")
read -r field_w field_h < <(magick identify -format '%w %h\n' "${work}/field.png")
logo_x="$(place "$WIDTH" "$logo_w" "$(key WatermarkHorizontalAlignment)")"
logo_y="$(place "$HEIGHT" "$logo_h" "$(key WatermarkVerticalAlignment)")"
field_x="$(place "$WIDTH" "$field_w" "$(key DialogHorizontalAlignment)")"
field_y="$(place "$HEIGHT" "$field_h" "$(key DialogVerticalAlignment)")"
bar_x="$(place "$WIDTH" "$bar_w" "$(key ProgressBarHorizontalAlignment)")"
bar_y="$(place "$HEIGHT" "$bar_h" "$(key ProgressBarVerticalAlignment)")"

# plymouthd wants a terminal, which neither a container nor CI has: script lends
# it one for as long as it runs. A virtual machine, as CI runs on, has a serial
# console, which turns Plymouth to text.
start() {
    local i
    script -qec "plymouthd --no-daemon --kernel-command-line='splash plymouth.ignore-serial-consoles' --tty=\$(tty) --debug-file=$(printf '%q' "${out}/plymouthd.log")" \
        /dev/null >/dev/null &
    daemon=$!
    for ((i = 0; i < 50; i++)); do
        plymouth --ping && break
        sleep 0.2
    done
    plymouth --ping || fail "plymouthd did not start"
    plymouth show-splash
}

stop() {
    plymouth quit
    wait "$daemon"
}

start
shot "${out}/boot.png" "${work}/logo.png" "$logo_x" "$logo_y"
plymouth ask-for-password --prompt='Please enter passphrase for disk root (cryptroot):' >/dev/null 2>&1 &
shot "${out}/password.png" "${work}/field.png" "$field_x" "$field_y"
stop

start
plymouth change-mode --updates
plymouth system-update --progress="$PROGRESS"
shot "${out}/updates.png" "${work}/bar.png" "$bar_x" "$bar_y"
stop
