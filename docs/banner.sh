#!/usr/bin/env bash
# Renders docs/banner.png out of two frames of make render, the wordmark in
# docs/wordmark.txt and the tagline in docs/README.md, by banner.py of
# murkl/workflows checked out next to this project. Needs chromium, python and
# ttf-firacode-nerd.
set -euo pipefail
cd "$(dirname "$0")/.."

# The README's tagline, the paragraph under its banner, so the banner cannot
# come to say something else. Its bold stays the README's.
tagline="$(awk '/src="banner\.png"/ { found = 1; next } found && NF { print; exit }' docs/README.md)"
case "$tagline" in
"<p>"*"</p>")
    tagline="${tagline#<p>}"
    tagline="${tagline%</p>}"
    ;;
*)
    echo "docs/README.md: no <p> line under the banner to take the tagline from" >&2
    exit 1
    ;;
esac
tagline="${tagline//<b>/}"
tagline="${tagline//<\/b>/}"

# Nord's frost, the accent of the System Manager's banner. The splash itself
# draws in snow storm, which the accent sets off.
accent="#88c0d0"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
{
    printf 'accent: "%s"\nlogo: |\n' "$accent"
    sed 's/^/  /' docs/wordmark.txt
} >"${work}/product.yaml"

# Three fifths of each screen, centred between the logo and the password field,
# so the splash fills its card.
for state in boot password; do
    read -r w h < <(magick identify -format '%w %h\n' "target/render/${state}.png")
    cw=$((w * 3 / 5)) ch=$((h * 3 / 5))
    magick "target/render/${state}.png" -crop "${cw}x${ch}+$(((w - cw) / 2))+$((h * 61 / 100 - ch / 2))" +repage \
        "${work}/${state}.png"
done

python3 ../workflows/banner/banner.py \
    --product "${work}/product.yaml" \
    --logo art/watermark.svg \
    --card "${work}/boot.png" \
    --card "${work}/password.png" \
    --tagline "$tagline" \
    --cell 8
