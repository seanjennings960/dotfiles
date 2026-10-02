.PHONY: lint-activation
lint: lint-activation
lint-activation:
	shellcheck install.sh infectdots.sh
	ruff check scripts/activation
