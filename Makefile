ADDON_NAME := Spotter
WOW_ADDONS := /mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns
RELEASE_DIR := .release/$(ADDON_NAME)
DEPLOY_DIR  := $(WOW_ADDONS)/$(ADDON_NAME)
LIBS_DIR    := $(DEPLOY_DIR)/Libs

.PHONY: help build deploy dev lint clean externals sync

help:
	@echo "Spotter dev targets:"
	@echo "  make dev       - copy working dir + Libs into WoW AddOns (no git needed)"
	@echo "  make build     - run BigWigs packager (-dlz), populates .release/ (uses git)"
	@echo "  make deploy    - rsync .release/Spotter/ into the WoW AddOns folder"
	@echo "  make lint      - run luacheck on the source"
	@echo "  make externals - re-pull HereBeDragons (same as build)"
	@echo "  make clean     - remove .release/"
	@echo ""
	@echo "Inner loop: edit .lua files, 'make dev', /reload in game."

# ---------------------------------------------------------------------------
# dev: fast local deploy from working directory. No git dependency.
# Copies all .lua/.xml/.toc files directly, preserves Libs if already present,
# and pulls Libs from .release/ if available (run 'make build' once to fetch).
# ---------------------------------------------------------------------------
dev:
	@mkdir -p "$(DEPLOY_DIR)"
	rsync -a --exclude='.release' --exclude='.git' --exclude='.github' \
		--exclude='Libs' --exclude='.luacheckrc' --exclude='Makefile' \
		--exclude='.pkgmeta' --exclude='.gitignore' --exclude='scripts' \
		./ "$(DEPLOY_DIR)/"
	@# Ensure Libs/ exists — copy from .release if we have it and deploy is missing it
	@if [ ! -d "$(LIBS_DIR)" ] && [ -d "$(RELEASE_DIR)/Libs" ]; then \
		cp -r "$(RELEASE_DIR)/Libs" "$(LIBS_DIR)"; \
		echo "Copied Libs/ from .release/"; \
	elif [ ! -d "$(LIBS_DIR)" ]; then \
		echo "WARNING: $(LIBS_DIR) missing. Run 'make build' once to fetch externals."; \
	fi
	@echo "Deployed to: $(DEPLOY_DIR)"

# ---------------------------------------------------------------------------
# build: full release via BigWigs packager. Requires git-tracked files.
# ---------------------------------------------------------------------------
build:
	curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -dlz

externals: build

deploy:
	@test -d "$(RELEASE_DIR)" || (echo "No $(RELEASE_DIR) — run 'make build' first" && exit 1)
	@mkdir -p "$(DEPLOY_DIR)"
	rsync -a --delete "$(RELEASE_DIR)/" "$(DEPLOY_DIR)/"
	@echo "Deployed to: $(DEPLOY_DIR)"

# Alias for backwards compat with the old sync target
sync: dev

lint:
	luacheck .

clean:
	rm -rf .release
