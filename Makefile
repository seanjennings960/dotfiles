TEST_PYTHON ?= /opt/dotfiles/test-venv/bin/python

.PHONY: test test-python lint
test: lint test-python

lint:
	bash -n install.sh infectdots.sh bashrc bash_aliases tmux/tmux_neww.sh .devcontainer/install-toolchain.sh
	zsh -n zshrc
	shellcheck .devcontainer/install-toolchain.sh
	ruff check tests

test-python:
	$(TEST_PYTHON) -m pytest $(PYTEST_ARGS)
