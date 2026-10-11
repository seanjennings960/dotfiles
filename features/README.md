# Personal devtools Feature

`src/devtools` defines the personal tool installation layer. Every project owns
its `.devcontainer/Dockerfile` and project dependencies. Applying this Feature
adds personal tools to that project's single image, including dotfiles' own
development image.

The Feature installs `dev`, Git, tmux, Vim, Bash completion, Zsh, ripgrep, Neovim
0.12.5, Ruff 0.16.10, Pyright 1.1.414 (Node 22.20.0), and OpenCode 1.18.34 on
Debian/Ubuntu with Python 3.11 or newer. Linux ARM64 on Ubuntu 24.04 is verified;
x86_64 download selections are present but not natively verified. The launcher
uses `/opt/dotfiles-dev/venv`, independently of
project virtual environments. Python, pip, and project executable precedence are
not redirected to that private environment.

## Local development

From the dotfiles checkout:

```sh
git submodule update --init --recursive --checkout
python3 scripts/prepare_feature.py
devcontainer build --workspace-folder . --image-name dotfiles-devtools:local
```

`devcontainer up` also prepares the Feature through the initialize hook. The
preparation script requires clean plugin checkouts at their recorded commits.
It copies launcher source, defaults, plugins, tests, and the Feature definition
into `.devcontainer/features/devtools`, recording SHA256 hashes and file modes
in `source.json` and revisions in `source/plugin-pins.txt`. The installer verifies
the hashes and restores modes normalized by the Dev Container CLI. The generated
directory is ignored by Git and can be regenerated.

For another project:

```sh
python3 scripts/prepare_feature.py --project ../agents-model
```

That project's devcontainer references `./features/devtools`. Local Features
must reside under the consuming project's `.devcontainer` directory. The source
definition and launcher stay in dotfiles; the generated copy is a build input.
Run `dev activate` as that project's development user after creation to link
packaged defaults. This repository's post-create hook additionally runs
`make test-env`; other projects need not install dotfiles' test dependencies.

Package the prepared, self-contained Feature with:

```sh
devcontainer features package .devcontainer/features
```

Distribution through an OCI registry is a later step. Personal version selections
and defaults belong to the Feature/toolset; project-specific tools such as ProB
belong to the consuming project.

## Execution contract

The Feature sets `DEV_ENVIRONMENT=container`. In an installed container, bare
`dev` reconnects to local tmux work, `dev env` reports container context, and
`dev exec` executes locally with the caller's working directory and streams.
The launcher rejects requests to enter a different environment. Runtime-managed
container creation and rebuild are still pending.

The Feature is an installation layer. Agent isolation requires the separate
workspace, resource, and runtime restrictions in `docs/architecture.md`.

Personal tool archives are checksum-verified; the npm lock records Pyright and
the launcher lock pins Click and its build prerequisites. This project's base
image is pinned by digest. Apt packages remain build-time selections and Python
locks pin versions without artifact hashes. These limits prevent a claim of a
fully reproducible image from pinned inputs alone.

## Installed verification

After `devcontainer up --workspace-folder .`:

```sh
devcontainer exec --workspace-folder . dev test -q --opencode
devcontainer exec --workspace-folder . /opt/dotfiles-dev/venv/bin/python -I /opt/dotfiles-dev/source/tests/container_smoke.py
devcontainer exec --workspace-folder . make lint
```

The smoke check runs as non-root with a project venv lacking launcher dependencies,
checks faithful execution and workspace discovery, and reconnects through fresh
launcher processes. The full suite also exercises activated Neovim and tmux.
