{ lib, python3Packages, git, tmux }:

python3Packages.buildPythonApplication {
  pname = "dotfiles-dev";
  version = "0.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../pyproject.toml
      ../dotfiles_dev
      ../tests/test_dev_cli.py
    ];
  };

  build-system = [ python3Packages.setuptools ];
  dependencies = [ python3Packages.click ];
  # Use the version pinned by flake.lock instead of the PyPI-specific exact pin.
  pythonRelaxDeps = [ "click" ];

  nativeCheckInputs = [ python3Packages.pytestCheckHook git ];
  pytestFlags = [ "tests/test_dev_cli.py" ];
  pythonImportsCheck = [ "dotfiles_dev.cli" ];

  # Keep project tools first, while supplying launcher runtime dependencies.
  makeWrapperArgs = [ "--suffix PATH : ${lib.makeBinPath [ git tmux ]}" ];

  meta = {
    description = "Workspace launcher with local tmux sessions";
    mainProgram = "dev";
    platforms = [ "aarch64-darwin" "aarch64-linux" ];
  };
}
