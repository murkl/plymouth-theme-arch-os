# Recipes are bash and stop at the first failing command, in pipes too.
SHELL       := bash
.SHELLFLAGS := -eu -o pipefail -c

# The date names the base, the digest pins it. CI runs in the same.
IMAGE := archlinux:base-devel-20261011.0.609700@sha256:061679925e5d5028f2df9395d441ce6c4b9accf0157ff3486c06b6962e014ef1

# What make check needs, then what tools/render.sh needs. CI installs both.
PACKAGES        := shellcheck actionlint zizmor imagemagick librsvg plymouth
RENDER_PACKAGES := plymouth gtk3 xorg-server-xvfb xorg-xwd xdotool imagemagick

.PHONY: all theme check lint theme-check aur-check render banner packages github clean

all: theme

# src/ out of art/ and the spinner theme of the installed plymouth.
theme:
	tools/assets.sh src

# The one command that has to pass before a commit.
check: lint theme-check aur-check

lint:
	shellcheck tools/*.sh docs/*.sh .github/*.sh
	actionlint
	zizmor --offline --quiet .github/workflows

# src/ as make theme writes it: the same files, each image the same to the eye.
theme-check:
	rm -rf target/theme
	tools/assets.sh target/theme
	cp src/arch-os.plymouth target/theme/
	diff <(ls src) <(ls target/theme)
	for file in target/theme/*.png; do \
		magick compare -metric AE -fuzz 2% "$$file" "src/$${file##*/}" null: 2>/dev/null || { \
			echo "theme-check: src/$${file##*/} is not what make theme writes" >&2; exit 1; }; \
	done

# The package as a user builds it, stamped for a stand-in version. Its tarball
# holds only src/, the one folder package() reads.
aur-check:
	rm -rf target/aur
	mkdir -p target/aur
	tar --transform 's|^|plymouth-theme-arch-os-0.0.0/|' -czf target/aur/plymouth-theme-arch-os-0.0.0.tar.gz src
	tools/aur.sh stamp 0.0.0 target/aur/plymouth-theme-arch-os-0.0.0.tar.gz target/aur
	tools/aur.sh build target/aur

# The splash as Plymouth draws it, in a throwaway container. The pictures land
# in target/render/.
render:
	mkdir -p target/render
	docker run --rm -v "$(CURDIR):/repo:ro" -v "$(CURDIR)/target/render:/out" $(IMAGE) bash -c \
		'pacman -Syu --noconfirm --needed $(RENDER_PACKAGES) >/dev/null && /repo/tools/render.sh /out; \
		status=$$?; chown -R $(shell id -u):$(shell id -g) /out; exit $$status'

# docs/banner.png out of make render.
banner: render
	docs/banner.sh

packages:
	@echo $(PACKAGES) $(RENDER_PACKAGES)

# The repository's settings on GitHub, out of .github/settings/. Run by hand as
# an admin: a workflow may not change the rules it is held to.
github:
	.github/settings.sh

clean:
	rm -rf target
