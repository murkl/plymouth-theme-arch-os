#!/usr/bin/env bash
# The AUR package out of aur/: stamped for a source tarball, built as a user
# builds it, checked against src/, and pushed as the PKGBUILD's maintainer.
#
#   tools/aur.sh stamp <version> <tarball> <folder>
#   tools/aur.sh build <folder>
#   tools/aur.sh push <folder>     AUR_SSH_KEY, else the user's ssh
#   tools/aur.sh key               gh as an admin, by hand
set -euo pipefail
cd "$(dirname "$0")/.."

# A folder of the command's own, global so the trap that removes it still sees it.
work=""

# makepkg refuses root, which a CI container is. There it runs in the folder as
# a user of its own.
as_builder() {
    local dir="$1"
    shift
    if [ "$(id -u)" -eq 0 ]; then
        id builder >/dev/null 2>&1 || useradd --create-home builder
        chown -R builder "$dir"
        (cd "$dir" && runuser -u builder -- "$@")
    else
        (cd "$dir" && "$@")
    fi
}

# aur/PKGBUILD with its placeholders filled, and its .SRCINFO.
stamp() {
    local version="$1" tarball="$2" out="$3" sum
    mkdir -p "$out"
    sum="$(sha256sum "$tarball")"
    sed -e "s/{{VERSION}}/${version}/" -e "s/{{SHA256}}/${sum%% *}/" aur/PKGBUILD >"${out}/PKGBUILD"
    if grep -n '{{' "${out}/PKGBUILD" >&2; then
        echo "aur: a placeholder is left" >&2
        exit 1
    fi
    as_builder "$out" makepkg --printsrcinfo >"${out}/.SRCINFO"
    grep -qx "	pkgver = ${version}" "${out}/.SRCINFO"
}

# The package, built as a user builds it. Read back: it installs src/ file for file.
build() {
    local dir
    dir="$(cd "$1" && pwd)"
    as_builder "$dir" makepkg --noconfirm
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    bsdtar -xf "$dir"/*.pkg.tar.zst -C "$work"
    diff -r "${work}/usr/share/plymouth/themes/arch-os" src
}

# A stamped folder in place of what the AUR has. The host key is the one whose
# fingerprint https://aur.archlinux.org names.
push() {
    local dir name version maintainer email
    dir="$(cd "$1" && pwd)"
    name="$(sed -n 's/^pkgbase = //p' "${dir}/.SRCINFO")"
    version="$(sed -n 's/^\tpkgver = //p' "${dir}/.SRCINFO")"
    maintainer="$(sed -n 's/^# Maintainer: \(.* <.*>\)$/\1/p' "${dir}/PKGBUILD")"
    if [ -z "$name" ] || [ -z "$version" ] || [ -z "$maintainer" ]; then
        echo "aur: ${dir} holds no stamped package" >&2
        exit 1
    fi
    email="${maintainer##*<}"
    export GIT_AUTHOR_NAME="${maintainer% <*}" GIT_AUTHOR_EMAIL="${email%>}"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    if [ -n "${AUR_SSH_KEY:-}" ]; then
        mkdir -m 700 "${work}/ssh"
        printf '%s\n' "$AUR_SSH_KEY" >"${work}/ssh/key"
        chmod 600 "${work}/ssh/key"
        echo 'aur.archlinux.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuBKrPzbawxA/k2g6NcyV5jmqwJ2s+zpgZGZ7tpLIcN' >"${work}/ssh/known_hosts"
        export GIT_SSH_COMMAND="ssh -i ${work}/ssh/key -o IdentitiesOnly=yes -o UserKnownHostsFile=${work}/ssh/known_hosts -o StrictHostKeyChecking=yes"
    fi
    git clone --quiet "ssh://aur@aur.archlinux.org/${name}.git" "${work}/repo"
    cd "${work}/repo"
    # What is there goes first, so a file the release no longer has goes with it.
    git rm -q -r --ignore-unmatch -- .
    cp "${dir}/PKGBUILD" "${dir}/.SRCINFO" .
    git add -A
    if git diff --cached --quiet; then
        echo "aur: ${name} ${version} is there already"
        return 0
    fi
    git commit --quiet -m "$version"
    git push --quiet origin HEAD:master
    echo "aur: ${name} ${version}"
}

# The release's own key for the AUR: made here, kept only as the secret
# AUR_SSH_KEY of the environment aur, which version tags alone may use. Prints
# the public half for the AUR account's SSH Public Key field, as one more line
# there.
key() {
    local repo
    repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    ssh-keygen -q -t ed25519 -N '' -C "${repo} release" -f "${work}/key"

    gh api --method PUT "repos/${repo}/environments/aur" --input - >/dev/null <<'JSON'
{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
JSON
    # One that exists already answers 303, and gh follows it there.
    gh api --method POST "repos/${repo}/environments/aur/deployment-branch-policies" \
        -f name="*.*.*" -f type=tag >/dev/null
    gh secret set AUR_SSH_KEY --env aur --repo "$repo" <"${work}/key"

    echo "Add this line at https://aur.archlinux.org/account/ under SSH Public Key:"
    cat "${work}/key.pub"
}

case "${1:-}" in
stamp | build | push | key) "$@" ;;
*)
    echo "usage: tools/aur.sh stamp|build|push|key" >&2
    exit 2
    ;;
esac
