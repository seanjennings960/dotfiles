FROM mcr.microsoft.com/devcontainers/base:1-ubuntu-24.04@sha256:763eca1839b2c6366f25b9c2b4c75c46e3d485a8d1b95f725e829397398a4c46

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        curl \
        diffutils \
        git \
        make \
        ncurses-term \
        python3 \
        python3-venv \
        python-is-python3 \
        ripgrep \
        shellcheck \
        tmux \
        vim \
        zsh \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/install-toolchain.sh .devcontainer/package.json .devcontainer/package-lock.json /tmp/dotfiles-toolchain/
RUN bash /tmp/dotfiles-toolchain/install-toolchain.sh \
    && rm -rf /tmp/dotfiles-toolchain

COPY requirements-dev.lock /tmp/requirements-dev.lock
RUN python3 -m venv /opt/dotfiles/test-venv \
    && /opt/dotfiles/test-venv/bin/python -m pip install --no-cache-dir -r /tmp/requirements-dev.lock \
    && rm /tmp/requirements-dev.lock

USER vscode
