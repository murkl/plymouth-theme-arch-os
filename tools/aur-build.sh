#!/usr/bin/env bash
# Builds the package in a folder tools/aur.sh stamped, as a user builds it, and
# checks that it installs src/ file for file. makepkg refuses root, which a CI
# container is, so there it builds as a user of its own.
# Usage: aur-build.sh <folder>
set -euo pipefail

dir="$(cd "$1" && pwd)"
cd "$(dirname "$0")/.."

runner=()
if [ "$(id -u)" -eq 0 ]; then
    id builder >/dev/null 2>&1 || useradd --create-home builder
    chown -R builder "$dir"
    runner=(runuser -u builder --)
fi
(cd "$dir" && "${runner[@]}" makepkg --noconfirm)

package="$(mktemp -d)"
trap 'rm -rf "$package"' EXIT
bsdtar -xf "$dir"/*.pkg.tar.zst -C "$package"
diff -r "${package}/usr/share/plymouth/themes/arch-os" src
