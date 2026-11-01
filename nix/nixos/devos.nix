{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.devos;
  tools = self.packages.${pkgs.stdenv.hostPlatform.system};
  terminal = pkgs.writeShellApplication {
    name = "devos-terminal";
    runtimeInputs = [
      tools.toolset
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      mkdir -p "$HOME/workspaces"
      cd "$HOME/workspaces"
      systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR
      systemctl --user start devos-tmux.service
      while true; do
        dev --workspace "$HOME/workspaces" || true
        printf '\nDevOS: [Enter] reconnect, [s] recovery shell, [q] power off: '
        read -r choice || exit 0
        case "$choice" in
          s) zsh ;;
          q) systemctl poweroff ;;
        esac
      done
    '';
  };
  session = pkgs.writeShellApplication {
    name = "devos-session";
    text = ''
      exec ${pkgs.ghostty}/bin/ghostty \
        --gtk-single-instance=false \
        --config-file=${tools.ghostty-config}/share/ghostty/config.ghostty \
        --window-decoration=false \
        -e ${terminal}/bin/devos-terminal
    '';
  };
in
{
  options.services.devos = {
    enable = lib.mkEnableOption "the DevOS single-app development interface";
    user = lib.mkOption {
      type = lib.types.str;
      default = "dev";
      description = "Local user automatically logged into the DevOS interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    time.timeZone = lib.mkDefault "UTC";
    fonts.packages = [ pkgs.dejavu_fonts ];
    environment.systemPackages = [
      tools.toolset
      pkgs.ghostty
      pkgs.git
    ];

    users.users.${cfg.user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      linger = true;
    };

    services.cage = {
      enable = true;
      user = cfg.user;
      program = "${session}/bin/devos-session";
      # Allow switching to a recovery virtual console.
      extraArguments = [ "-s" ];
    };
    systemd.services.cage-tty1.serviceConfig = {
      Restart = "always";
      RestartSec = 3;
    };

    # Keep workspace processes outside the graphical session's service cgroup.
    # The terminal starts this after importing its Wayland environment.
    systemd.user.services.devos-tmux = {
      description = "DevOS workspace tmux server";
      serviceConfig = {
        ExecStart = "${tools.tmux}/bin/tmux -L dotfiles-dev -D";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
