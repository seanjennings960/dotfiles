FROM mcr.microsoft.com/devcontainers/base:1-ubuntu-24.04@sha256:763eca1839b2c6366f25b9c2b4c75c46e3d485a8d1b95f725e829397398a4c46

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        make \
        python3 \
        python3-venv \
        shellcheck \
    && rm -rf /var/lib/apt/lists/*

USER vscode
