# Personal devtools Feature

`src/devtools` defines the personal tool installation layer. Every project owns
its `.devcontainer/Dockerfile` and project dependencies. Applying this Feature
adds personal tools to that project's single image, including dotfiles' own
development image.

The initial Feature installs `dev`, Git, tmux, Vim, and Zsh on Debian/Ubuntu with
Python 3.11 or newer. The launcher uses `/opt/dotfiles-dev/venv`, independently of
project virtual environments. Python, pip, and project executable precedence are
not redirected to that private environment.

Launcher virtual-environment creation and package installation use the shared
`dotfiles_dev/install_launcher.py` helper. The Feature keeps Debian package
installation, root checks, and the system command link in `install.sh`; host
activation keeps Python bootstrap and shell activation in `activate.sh`.

## Local development

From the dotfiles checkout:

```sh
python3 scripts/prepare_feature.py
devcontainer build --workspace-folder . --image-name dotfiles-devtools:local
```

`devcontainer up` also prepares the Feature through the initialize hook. The
preparation script copies the current launcher source and Feature definition
into `.devcontainer/features/devtools`, with source-file hashes in `source.json`.
The generated directory is ignored by Git and can be regenerated.

For another project:

```sh
python3 scripts/prepare_feature.py --project ../agents-model
```

That project's devcontainer references `./features/devtools`. Local Features
must reside under the consuming project's `.devcontainer` directory. The source
definition and launcher stay in dotfiles; the generated copy is a build input.

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

Ubuntu package versions and the Python build backend are currently resolved at
build time. The launcher source hashes and exact Click dependency are recorded;
the complete image is not yet reproducible from pinned package inputs alone.
