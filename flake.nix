{
  description = "Devchain terminal development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          wheelhouse = pkgs.callPackage ./nix/wheelhouse.nix { };
          dev = pkgs.callPackage ./nix/package.nix { inherit wheelhouse; };
        in
        {
          inherit dev;
          default = dev;
        });

      checks = forAllSystems (system: {
        dev = self.packages.${system}.dev;
      });

      devShells = forAllSystems (system:
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
        });
    };
}
