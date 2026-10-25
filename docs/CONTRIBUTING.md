# Contributing

Every change comes back to `main` as one squash commit under its pull request title, in **[Conventional Commits](https://www.conventionalcommits.org)**, which sorts it into the release notes.

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

A version tag on an up-to-date `main` releases. The run publishes the release with its notes and source tarball, then pushes the AUR package. The notes and their checks come from **[murkl/workflows](https://github.com/murkl/workflows)**, checked out next to this project:

```
../workflows/notes/notes.sh 1.1.0 && git tag 1.1.0 && git push origin 1.1.0
```

- `fix:` raises the patch, `feat:` the minor, `feat!:` the major version
- `AUR_SSH_KEY` from `tools/aur.sh key`, whose public half goes into the AUR account. Only version tags may use it
- A Publish that failed runs again with **Re-run failed jobs**. Tags never move, so a fix after a release is a new version

`make github` applies `.github/settings/` to the repository. `ruleset-tags.json` keeps every tag from being moved or deleted.
