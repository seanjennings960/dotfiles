.PHONY: lint-shells
lint: lint-shells
lint-shells:
	shellcheck bashrc bash_aliases
