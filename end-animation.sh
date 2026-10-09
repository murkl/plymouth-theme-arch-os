#!/usr/bin/env bash
# Builds src/animation-*.png, the end animation two-step plays when the splash
# ends: the logo and the spinner fade into the background. Needs ImageMagick.
#
# two-step centres the end animation on the spinner and the logo on the screen,
# so the distance between them grows with the screen. Each frame is therefore a
# column as wide as the logo and tall enough to reach it on a screen up to 2600
# points high, filled with the background at a rising opacity: what lies under
# it fades, and the rest is the background drawn on itself.
set -Eeuo pipefail
cd "$(dirname "$0")/src"

# Half a second at the 30 frames per second two-step plays.
FRAMES=15
HEIGHT=1200

WIDTH="$(magick identify -format '%w' watermark.png)"

# The spinner stops on its last frame, which is where the fade picks it up.
SPINNER="$(printf '%s\n' throbber-*.png | sort | tail -n1)"
read -r SPINNER_W SPINNER_H < <(magick identify -format '%w %h\n' "$SPINNER")

# The background the theme draws, read from the theme itself.
hex="$(sed -n 's/^BackgroundStartColor=0x\([0-9a-fA-F]\{6\}\).*/\1/p' arch-os.plymouth)"
[ -n "$hex" ] || {
    echo "Error: arch-os.plymouth has no BackgroundStartColor=0xRRGGBB.." >&2
    exit 1
}
BACKGROUND="$((16#${hex:0:2})),$((16#${hex:2:2})),$((16#${hex:4:2}))"

rm -f animation-*.png
for ((i = 0; i < FRAMES; i++)); do
    # Smoothstep: it eases out of the splash and into the background.
    alpha="$(awk -v t="$i" -v n="$((FRAMES - 1))" 'BEGIN { t /= n; printf "%.4f", t * t * (3 - 2 * t) }')"
    magick -size "${WIDTH}x${HEIGHT}" xc:none \
        "$SPINNER" -geometry "+$(((WIDTH - SPINNER_W) / 2))+$(((HEIGHT - SPINNER_H) / 2))" -composite \
        \( -size "${WIDTH}x${HEIGHT}" "xc:rgba(${BACKGROUND},${alpha})" \) -composite \
        -strip -define png:exclude-chunks=date,time \
        "PNG32:$(printf 'animation-%04d.png' "$((i + 1))")"
done
