#!/usr/bin/env bash
# Renders the theme's images into a folder, in the colors of src/arch-os.plymouth:
# the logo and the field out of art/, the spinner, icons and keymap labels out of
# the installed plymouth, and the end animation.
# Usage: assets.sh <folder>
set -euo pipefail

out="$(mkdir -p "$1" && cd "$1" && pwd)"
cd "$(dirname "$0")/.."

# keymap-render.png has to match the label offsets compiled into this plymouth.
SPINNER=/usr/share/plymouth/themes/spinner
# Without the chunks that carry the time, so a rerun writes the same bytes.
PNG=(-strip -define 'png:exclude-chunks=date,time')

# A color of the theme as rrggbb. Opaque, as the end animation fades into it.
color() {
    local hex
    hex="$(sed -n "s/^$1=0x\([0-9a-f]\{6\}\)ff$/\1/p" src/arch-os.plymouth)"
    if [ -z "$hex" ]; then
        echo "assets: src/arch-os.plymouth has no $1=0xrrggbbff" >&2
        exit 1
    fi
    echo "$hex"
}
background="$(color BackgroundStartColor)"
foreground="$(color ProgressBarForegroundColor)"
field="$(color ProgressBarBackgroundColor)"
text="$(color ConsoleLogTextColor)"

# A color as the three fractions -fx reads.
fractions() {
    local c
    for c in "${1:0:2}" "${1:2:2}" "${1:4:2}"; do
        awk -v v="$((16#$c))" 'BEGIN { printf "%.6f ", v / 255 }'
    done
}

rsvg-convert -s <(printf 'path { fill: #%s; }\n' "$foreground") art/watermark.svg |
    magick png:- "${PNG[@]}" "PNG32:${out}/watermark.png"

# two-step draws lock.png left of entry.png, so one field is cut in two.
LOCK=8
rsvg-convert -s <(printf 'rect { fill: #%s; }\n' "$field") art/field.svg |
    magick png:- \( +clone -crop "${LOCK}x+0+0" +repage "${PNG[@]}" -write "PNG32:${out}/lock.png" +delete \) \
        -crop "+${LOCK}+0" +repage "${PNG[@]}" "PNG32:${out}/entry.png"

# Upstream draws these in one grey whose shades carry detail: the mean of its
# opaque pixels becomes the theme's color, the alpha stays.
# Usage: tint <file> <rrggbb>
tint() {
    local ink
    ink="$(magick -quiet "${SPINNER}/$1" -colorspace gray \( -clone 0 -fx 'u.a == 1 ? u.r : 0' \) \
        \( -clone 0 -fx 'u.a == 1' \) -delete 0 -alpha off -format '%[fx:mean] ' info: |
        awk '{ printf "%.4f", $1 / $2 * 100 }')"
    magick -quiet "${SPINNER}/$1" -colorspace gray -channel RGB -level "0,${ink}%" -colorspace sRGB \
        +level-colors "black,#$2" +channel "${PNG[@]}" "PNG32:${out}/$1"
}
tint bullet.png "$foreground"
tint keyboard.png "$text"
tint capslock.png "$text"
tint keymap-render.png "$text"

# Upstream's spinner is an arc in a light grey over a track in a darker one at
# low alpha. Each pixel is split into both and redrawn as the progress bar is.
throbbers=("$SPINNER"/throbber-*.png)
# Pixels below a tenth of alpha are edges, which carry no ink of their own. The
# track comes in neighbouring greys: its brightest is the ink, so all turn opaque.
low="$(magick -quiet "${throbbers[@]}" +append -fx 'u.a >= 0.1 ? u.g : 1' -alpha off -format '%[fx:minima]' info:)"
track="$(magick -quiet "${throbbers[@]}" +append -fx "u.a >= 0.1 && u.g < ${low} + 0.016 ? u.g : 0" -alpha off -format '%[fx:maxima]' info:)"
track_alpha="$(magick -quiet "${throbbers[@]}" +append -fx "u.g < ${low} + 0.016 ? u.a : 0" -alpha off -format '%[fx:maxima]' info:)"
arc="$(magick -quiet "${throbbers[@]}" +append -fx 'u.a >= 0.9 ? u.g : 0' -alpha off -format '%[fx:maxima]' info:)"
read -r arc_r arc_g arc_b <<<"$(fractions "$foreground")"
read -r track_r track_g track_b <<<"$(fractions "$field")"
split="share = max(0, min(1, (u.g - ${track}) / (${arc} - ${track}))); gain = share + (1 - share) / ${track_alpha}"
ink() { echo "${split}; ($1 * share + $2 * (1 - share) / ${track_alpha}) / gain"; }
rm -f "$out"/throbber-*.png
for frame in "${throbbers[@]}"; do
    magick -quiet "$frame" -alpha set \
        -channel A -fx "${split}; min(1, u.a * gain)" \
        -channel R -fx "$(ink "$arc_r" "$track_r")" \
        -channel B -fx "$(ink "$arc_b" "$track_b")" \
        -channel G -fx "$(ink "$arc_g" "$track_g")" +channel \
        "${PNG[@]}" "PNG32:${out}/${frame##*/}"
done

# Each frame is a column as wide as the logo, centred on the spinner and tall
# enough to reach the logo on screens up to 2600 points high. 15 frames are half
# a second at the 30 per second two-step plays.
FRAMES=15
HEIGHT=1200
width="$(magick identify -format '%w' "${out}/watermark.png")"
rgb="$((16#${background:0:2})),$((16#${background:2:2})),$((16#${background:4:2}))"

# The spinner stops on its last frame, which is where the fade picks it up.
frames=("$out"/throbber-*.png)
spinner="${frames[-1]}"
read -r spinner_w spinner_h < <(magick identify -format '%w %h\n' "$spinner")

rm -f "$out"/animation-*.png
for ((i = 0; i < FRAMES; i++)); do
    # Smoothstep: it eases out of the splash and into the background.
    alpha="$(awk -v t="$i" -v n="$((FRAMES - 1))" 'BEGIN { t /= n; printf "%.4f", t * t * (3 - 2 * t) }')"
    magick -size "${width}x${HEIGHT}" xc:none \
        "$spinner" -geometry "+$(((width - spinner_w) / 2))+$(((HEIGHT - spinner_h) / 2))" -composite \
        \( -size "${width}x${HEIGHT}" "xc:rgba(${rgb},${alpha})" \) -composite \
        "${PNG[@]}" "PNG32:$(printf '%s/animation-%04d.png' "$out" "$((i + 1))")"
done
