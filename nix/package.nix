{ lib, stdenvNoCC, hatch, python3, makeWrapper, git, tmux, wheelhouse }:

let
  project = (builtins.fromTOML (builtins.readFile ../pyproject.toml)).project;
in
stdenvNoCC.mkDerivation {
  pname = project.name;
  version = project.version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../pyproject.toml
      ../dotfiles_dev
      ../tests/test_dev_cli.py
    ];
  };

  nativeBuildInputs = [ python3 makeWrapper ];
  nativeCheckInputs = [ git ];
  doCheck = true;

  # Hatch/pip install Python dependencies from this fixed-hash wheel cache.
  PIP_NO_INDEX = "1";
  PIP_FIND_LINKS = "${wheelhouse}";
  PIP_DISABLE_PIP_VERSION_CHECK = "1";
  HATCH_PYTHON = "${python3}/bin/python3";
  HATCH_PYTHON_AUTO_INSTALL = "0";
  VIRTUALENV_NO_PERIODIC_UPDATE = "1";

  preBuild = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
  '';

  buildPhase = ''
    runHook preBuild
    ${lib.getExe hatch} build -t wheel
    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck
    ${lib.getExe hatch} run test tests/test_dev_cli.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    python3 -m venv "$out/libexec/dev"
    "$out/libexec/dev/bin/python" -m pip install --no-compile dist/*.whl
    mkdir -p "$out/bin"
    makeWrapper "$out/libexec/dev/bin/dev" "$out/bin/dev" \
      --suffix PATH : ${lib.makeBinPath [ git tmux ]}
    runHook postInstall
  '';

  meta = {
    description = "Workspace launcher with local tmux sessions";
    mainProgram = "dev";
    platforms = [ "aarch64-darwin" "aarch64-linux" ];
  };
}
