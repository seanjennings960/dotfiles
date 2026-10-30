{
  lib,
  stdenvNoCC,
  runCommand,
  writeShellApplication,
  bashInteractive,
  tmux,
  xclip,
  wl-clipboard,
  resurrect,
}:

let
  clipboard = writeShellApplication {
    name = "tmux-clipboard";
    runtimeInputs = lib.optionals stdenvNoCC.isLinux [
      xclip
      wl-clipboard
    ];
    text =
      if stdenvNoCC.isDarwin then
        ''
          exec /usr/bin/pbcopy
        ''
      else
        ''
          if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
            exec wl-copy
          elif [ -n "''${DISPLAY:-}" ]; then
            exec xclip -selection clipboard -in
          else
            # tmux also sends OSC 52; consume the pipe when no display is available.
            cat >/dev/null
          fi
        '';
  };

  config = runCommand "devchain-tmux.conf" { } ''
    substitute ${../config/tmux.conf} "$out" \
      --replace-fail /bin/bash ${bashInteractive}/bin/bash \
      --replace-fail '~/.tmux.conf' "$out" \
      --replace-fail 'xclip -sel clip -i' '${lib.getExe clipboard}'
    printf '\nset -g set-clipboard on\n' >> "$out"
    printf 'run-shell "%s/resurrect.tmux"\n' '${resurrect}' >> "$out"
  '';
in
writeShellApplication {
  name = "tmux";
  text = ''
    exec ${lib.getExe tmux} -f ${config} "$@"
  '';
  meta.description = "tmux with Devchain bindings and platform clipboard support";
  passthru.configuration = config;
}
