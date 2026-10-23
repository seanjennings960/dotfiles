DEVCONTAINER ?= devcontainer
DOCKER ?= docker
DEV_IMAGE ?= dotfiles-devchain:local

.PHONY: build test smoke feature

build: feature
	$(DEVCONTAINER) build --workspace-folder . --image-name $(DEV_IMAGE)

test: build
	@set -eu; \
	collection=$$(mktemp -d); \
	trap 'rm -rf "$$collection"' EXIT; \
	mkdir -p "$$collection/src" "$$collection/test"; \
	cp -R .devcontainer/features/devchain "$$collection/src/devchain"; \
	cp -RL features/test/devchain "$$collection/test/devchain"; \
	$(DEVCONTAINER) features test \
		--project-folder "$$collection" \
		--features devchain \
		--base-image $(DEV_IMAGE) \
		--remote-user vscode

smoke: build
	@set -eu; \
	label=dotfiles.smoke=make-$$$$; \
	cleanup() { \
		container_id=$$($(DOCKER) ps -aq --filter "label=$$label"); \
		if [ -n "$$container_id" ]; then $(DOCKER) rm -f "$$container_id" >/dev/null; fi; \
	}; \
	trap cleanup EXIT; \
	$(DEVCONTAINER) up --workspace-folder . --id-label "$$label"; \
	$(DEVCONTAINER) exec --workspace-folder . --id-label "$$label" \
		dev exec pytest -q tests/container_smoke.py

feature:
	mkdir -p .devcontainer/features
	rm -rf .devcontainer/features/devchain
	cp -RL features/src/devchain .devcontainer/features/
	rm -rf .devcontainer/features/devchain/dotfiles_dev/__pycache__
