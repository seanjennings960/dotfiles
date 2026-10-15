# Devchain Feature

`src/devchain` links to the root `install.sh`, `pyproject.toml`, and `dotfiles_dev/`.
`test/devchain` links to `tests/`. The Feature and host installation use the same
installer, package source, and tests.

`install.sh` downloads uv with curl, then runs `uv tool install`. uv manages Python
and the launcher's isolated environment. Host installations live in `.devtools`
and use an editable package. Container installations live in `/opt/devchain`,
with `dev` on PATH at `/usr/local/bin/dev`.

The base image must supply curl and CA certificates. Git and tmux are runtime
dependencies; projects supply these alongside any editors or shells they want.
The installer does not require system Python or pip.

## Build and test

From the repository root:

```sh
make build
make test
make smoke
```

`build` is the default target. `test` and `smoke` both depend on it. The Feature
test uses Dev Container CLI to install the Feature again and run
`tests/container_smoke.py` as `vscode`. The smoke target exercises the repository's
own devcontainer and removes its test container afterwards.

`make feature` copies the Feature into `.devcontainer/features/devchain`, following
the source links. This makes a self-contained build input under the consuming
project's `.devcontainer` directory, as required for a local Feature. There is no
separate preparation script. `devcontainer up` runs this target through the
initialize hook. The generated directory is ignored by Git.

## Use in another project

Copy the Feature with its links dereferenced:

```sh
mkdir -p ../my-project/.devcontainer/features
cp -RL features/src/devchain ../my-project/.devcontainer/features/
```

Add `"./features/devchain": {}` to that project's `features` configuration.

To create a distributable Feature archive:

```sh
make feature
devcontainer features package .devcontainer/features/devchain
```

## Execution contract

The Feature sets `DEV_ENVIRONMENT=container`. In a container, bare `dev` reconnects
to local tmux work, `dev env` reports container context, and `dev exec` executes
locally with the caller's working directory and streams. Project virtual
environments keep their own Python and packages. The launcher rejects requests
to enter a different environment.
