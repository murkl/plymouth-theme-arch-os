# Contributing

Every change comes back to `main` as one squash commit under its pull request title, in **[Conventional Commits](https://www.conventionalcommits.org)**: `fix:` releases a patch, `feat:` a minor and `feat!:` a major version.

## Commands

```
make theme         # src/ out of art/ and the installed plymouth
make check         # the gate CI runs
make render        # the splash as Plymouth draws it, into target/render/
make banner        # docs/banner.png out of make render, with chromium and ttf-firacode-nerd
```

```
sudo pacman -S --needed docker $(make -s packages)
```

## Rules

- `src/` is the theme as installed. Its images come from `make theme`, never from an editor
- `keymap-render.png` has to match the installed plymouth. CI checks it every month
- The Arch OS ISO patches `[boot-up]` and `TitleVerticalAlignment` in `src/arch-os.plymouth`. Both stay

## Releasing

Merging the pull request `chore: release x.y.z` tags the version, publishes the release with its source tarball and pushes the AUR package. Two secrets do it, which only `main` may use:

- `RELEASE_TOKEN` from `.github/release-token.sh`: a fine-grained token with Contents and Pull requests set to read and write
- `AUR_SSH_KEY` from `tools/aur-key.sh`, whose public half goes into the AUR account

A Publish that failed runs again under **Actions › CI › Run workflow** with the release's tag, once its cause is fixed on `main`.

`make github` applies `.github/settings/` to the repository.
