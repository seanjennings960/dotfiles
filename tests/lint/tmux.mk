.PHONY: lint-tmux
lint: lint-tmux
lint-tmux:
	shellcheck tmux/tmux_neww.sh
