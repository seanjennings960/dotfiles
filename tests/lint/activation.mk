.PHONY: lint-activation
lint: lint-activation
lint-activation:
	shellcheck install.sh infectdots.sh
	ruff check dotfiles_dev/activation.py tests/test_activation.py
