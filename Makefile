LAUNCHER_PYTHON ?= $(HOME)/.local/share/dotfiles/launcher/bin/python

.PHONY: launcher-env test test-env lint
launcher-env:
	bash .devcontainer/setup-launcher.sh

test:
	"$(LAUNCHER_PYTHON)" -I -m dotfiles_dev test $(PYTEST_ARGS)

# Explicit setup may download locked dependencies. Entry and test never install.
test-env:
	"$(LAUNCHER_PYTHON)" -I -m dotfiles_dev.testing --setup

lint:
	for script in .devcontainer/setup-launcher.sh install.sh infectdots.sh bashrc; do bash -n "$$script" || exit; done
	zsh -n zshrc
	shellcheck .devcontainer/setup-launcher.sh install.sh infectdots.sh

# Feature PRs can retain optional additional lint targets here.
-include $(wildcard tests/lint/*.mk)
