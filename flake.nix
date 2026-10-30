{
  description = "Devchain terminal development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          wheelhouse = pkgs.callPackage ./nix/wheelhouse.nix { };
          tmux = pkgs.callPackage ./nix/tmux.nix { };
          dev = pkgs.callPackage ./nix/package.nix { inherit wheelhouse tmux; };
        in
        {
          inherit dev tmux;
          default = dev;
        }
      );

      checks = forAllSystems (system: {
        dev = self.packages.${system}.dev;
      });

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
              set -- flake.nix nix/*.nix
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
              # Expose Hatch without propagating its own Python dependencies
              # into the project's environment through Nix setup hooks.
              (pkgs.writeShellScriptBin "hatch" ''
                exec ${pkgs.lib.getExe pkgs.hatch} "$@"
              '')
            ];
          };
        }
      );
    };
}
