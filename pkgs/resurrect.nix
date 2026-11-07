{
  lib,
  stdenvNoCC,
  runCommand,
  makeWrapper,
  bash,
  tmux,
  tmuxPlugins,
  coreutils,
  gnused,
  gnugrep,
  gawk,
  findutils,
  gnutar,
  gzip,
  procps,
  hostname,
}:

# Keep plugin dependencies local to its scripts rather than changing pane PATH.
runCommand "devchain-tmux-resurrect"
  {
    nativeBuildInputs = [
      makeWrapper
      bash
    ];
  }
  ''
    mkdir -p "$out"
    cp -R ${tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/. "$out/"
    chmod -R u+w "$out"
    patchShebangs "$out"
    for script in resurrect.tmux scripts/save.sh scripts/restore.sh; do
      wrapProgram "$out/$script" --prefix PATH : ${
        lib.makeBinPath (
          [
            bash
            tmux
            coreutils
            gnused
            gnugrep
            gawk
            findutils
            gnutar
            gzip
          ]
          ++ lib.optionals stdenvNoCC.isLinux [
            procps
            hostname
          ]
        )
      }
    done
  ''
