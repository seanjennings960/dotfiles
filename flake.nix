{
  description = "Devchain terminal development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          wheelhouse = pkgs.callPackage ./pkgs/wheelhouse.nix { };
          resurrect = pkgs.callPackage ./pkgs/resurrect.nix { };
          zsh = pkgs.callPackage ./pkgs/zsh.nix { };
          tmux = pkgs.callPackage ./pkgs/tmux.nix {
            inherit resurrect;
            configuredZsh = zsh;
          };
          markdown-preview = pkgs.callPackage ./pkgs/markdown-preview.nix { };
          nvim = pkgs.callPackage ./pkgs/neovim.nix { markdownPreview = markdown-preview; };
          opencode = pkgs.callPackage ./pkgs/opencode.nix { };
          dev = pkgs.callPackage ./modules/package.nix { inherit wheelhouse tmux; };
          transcribe = pkgs.callPackage ./pkgs/transcribe.nix { };
          microphone = pkgs.callPackage ./modules/devices/microphone.nix { };
          push-to-talk = pkgs.callPackage ./modules/voice/push-to-talk {
            inherit microphone transcribe;
          };
        in
        {
          inherit
            dev
            tmux
            nvim
            zsh
            opencode
            markdown-preview
            transcribe
            ;
          ghostty-config = pkgs.runCommand "devchain-ghostty-config" { } ''
            mkdir -p "$out/share/ghostty"
            cp ${./config/ghostty/config.ghostty} "$out/share/ghostty/config.ghostty"
          '';
          opencode-config = pkgs.runCommand "devchain-opencode-config" { } ''
            mkdir -p "$out/share/opencode/skills/unslop"
            cp ${./config/opencode/opencode.jsonc} "$out/share/opencode/opencode.jsonc"
            cp ${./config/opencode/cli.json} "$out/share/opencode/cli.json"
            cp ${./config/opencode/skills/unslop/SKILL.md} "$out/share/opencode/skills/unslop/SKILL.md"
          '';
          default = dev;
          toolset = pkgs.symlinkJoin {
            name = "devchain-toolset";
            paths = [
              dev
              tmux
              nvim
              zsh
              opencode
              markdown-preview
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ push-to-talk ];
          };
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          inherit microphone push-to-talk;
        }
      );

      checks = forAllSystems (
        system:
        {
          dev = self.packages.${system}.dev;
          toolset = self.packages.${system}.toolset;
          markdown-preview = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/markdown-preview-check.nix {
            markdownPreview = self.packages.${system}.markdown-preview;
            configuredNeovim = self.packages.${system}.nvim;
          };
        }
        // nixpkgs.lib.optionalAttrs (nixpkgs.lib.hasSuffix "-darwin" system) {
          push-to-talk = self.packages.${system}.push-to-talk;
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "format-nix";
          runtimeInputs = [ pkgs.nixfmt ];
          text = ''
            if [ "$#" -eq 0 ]; then
              set -- flake.nix pkgs/*.nix modules/*.nix modules/devices/*.nix modules/voice/push-to-talk/*.nix
            fi
            exec nixfmt "$@"
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            name = "devchain";
            packages = [
              pkgs.python3
              pkgs.cowsay
              pkgs.lolcat
              self.packages.${system}.opencode
              # Expose Hatch without propagating its own Python dependencies
              # into the project's environment through Nix setup hooks.
              (pkgs.writeShellScriptBin "hatch" ''
                exec ${pkgs.lib.getExe pkgs.hatch} "$@"
              '')
            ];
            shellHook = ''
              if [[ $- == *i* ]]; then
                printf '%s\n' 'Hello, Nix!' | ${pkgs.cowsay}/bin/cowsay | ${pkgs.lolcat}/bin/lolcat
              fi
            '';
          };
        }
      );
    };
}
