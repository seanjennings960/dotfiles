DEVCONTAINER ?= devcontainer
DOCKER ?= docker
PYTHON ?= python3
DEV_IMAGE ?= dotfiles-devtools:local
FEATURE_TEST_BASE ?= dotfiles-feature-test-base:local

.PHONY: test build smoke feature-test-base

test: feature-test-base
	$(PYTHON) scripts/prepare_feature.py
	@set -eu; \
	collection=$$(mktemp -d); \
	trap 'rm -rf "$$collection"' EXIT; \
	mkdir -p "$$collection/src" "$$collection/test"; \
	cp -R .devcontainer/features/devtools "$$collection/src/devtools"; \
	cp -R features/test/devtools "$$collection/test/devtools"; \
	$(DEVCONTAINER) features test \
		--project-folder "$$collection" \
		--features devtools \
		--base-image $(FEATURE_TEST_BASE) \
		--remote-user vscode

feature-test-base:
	$(DOCKER) build \
		--file .devcontainer/Dockerfile \
		--tag $(FEATURE_TEST_BASE) \
		.

build:
	$(PYTHON) scripts/prepare_feature.py
	$(DEVCONTAINER) build --workspace-folder . --image-name $(DEV_IMAGE)

smoke: build
	$(DEVCONTAINER) up --workspace-folder .
	$(DEVCONTAINER) exec --workspace-folder . \
		dev exec /opt/dotfiles-dev/venv/bin/python -B tests/container_smoke.py
