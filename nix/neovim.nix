{ neovim }:

neovim.override {
  withPython3 = false;
  withRuby = false;
  withNodeJs = false;
  configure = {
    customRC = ''
      lua dofile("${../config/nvim/init.lua}")
    '';
  };
}
