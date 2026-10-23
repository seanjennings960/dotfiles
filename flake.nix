{
  description = "Isolated dev launcher and development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
      packagesFor = system:
        let
          pkgs = import nixpkgs { inherit system; };
          python = pkgs.python311;
          runtime = python.withPackages (ps: [ ps.click ]);
          source = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.fileFilter (file: file.hasExt "py") ./dotfiles_dev;
          };
          launcher = editable:
            let
              bootstrap = pkgs.writeText "devchain.py" ''
                import os
                import sys

                source = ${if editable then ''os.environ.get("DEVCHAIN_SOURCE", "")'' else ''"${source}"''}
                if not source or not os.path.isfile(os.path.join(source, "dotfiles_dev", "__init__.py")):
                    sys.exit("dev: DEVCHAIN_SOURCE must point to a devchain checkout; rerun install.sh")

                # -I -S ignores caller Python settings and site hooks without
                # changing the environment inherited by dev exec.
                sys.path[:0] = [source, "${runtime}/${python.sitePackages}"]
                sys.argv[0] = "dev"
                from dotfiles_dev.cli import main
                main()
              '';
            in
            pkgs.writeShellScriptBin "dev" ''
              exec ${python.interpreter} -I -S ${bootstrap} "$@"
            '';
        in
        {
          default = launcher false;
          editable = launcher true;
        };
    in
    {
      packages = forEachSystem packagesFor;

      devShells = forEachSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              (pkgs.python311.withPackages (ps: [ ps.click ps.pytest ps.pexpect ]))
              pkgs.git
              pkgs.tmux
              pkgs.shellcheck
            ];
          };
        });
    };
}
