{
  lib,
  runCommand,
  makeWrapper,
  zsh,
  zsh-autosuggestions,
  git,
  coreutils,
}:

let
  config = runCommand "devchain-zsh-config" { } ''
    mkdir -p "$out"
    substitute ${../config/zsh/zshrc} "$out/.zshrc" \
      --replace-fail '@autosuggestions@' '${zsh-autosuggestions}'
  '';
in
runCommand "devchain-zsh"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta.mainProgram = "zsh";
  }
  ''
    mkdir -p "$out/bin"
    makeWrapper ${zsh}/bin/zsh "$out/bin/zsh" \
      --set ZDOTDIR ${config} \
      --suffix PATH : ${
        lib.makeBinPath [
          git
          coreutils
        ]
      }
  ''
