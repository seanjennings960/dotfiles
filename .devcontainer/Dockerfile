FROM mcr.microsoft.com/devcontainers/base:1-ubuntu-24.04

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git \
        shellcheck \
        tmux \
        vim \
        zsh \
    && rm -rf /var/lib/apt/lists/*

USER vscode
