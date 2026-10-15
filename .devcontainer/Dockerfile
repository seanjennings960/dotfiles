FROM mcr.microsoft.com/devcontainers/base:1-ubuntu-24.04

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git \
        python3 \
        python3-pytest \
        python3-venv \
        shellcheck \
        tmux \
        vim \
        xz-utils \
        zsh \
    && rm -rf /var/lib/apt/lists/*

USER vscode
