{ lib, neovim, vimPlugins, diffutils }:

neovim.override {
  withPython3 = false;
  withRuby = false;
  withNodeJs = false;
  extraMakeWrapperArgs = "--suffix PATH : ${lib.makeBinPath [ diffutils ]}";
  configure = {
    packages.devchain.start = [ vimPlugins.gruvbox vimPlugins.nerdtree vimPlugins.ctrlp-vim vimPlugins.undotree ];
    customRC = ''
      lua dofile("${../config/nvim/init.lua}")
    '';
  };
}
