{ neovim, vimPlugins }:

neovim.override {
  withPython3 = false;
  withRuby = false;
  withNodeJs = false;
  configure = {
    packages.devchain.start = [ vimPlugins.gruvbox vimPlugins.nerdtree ];
    customRC = ''
      lua dofile("${../config/nvim/init.lua}")
    '';
  };
}
