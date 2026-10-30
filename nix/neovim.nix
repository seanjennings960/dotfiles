{
  lib,
  neovim,
  vimPlugins,
  diffutils,
  ruff,
}:

neovim.override {
  withPython3 = false;
  withRuby = false;
  withNodeJs = false;
  extraMakeWrapperArgs = "--suffix PATH : ${
    lib.makeBinPath [
      diffutils
      ruff
    ]
  }";
  configure = {
    packages.devchain.start = [
      vimPlugins.gruvbox
      vimPlugins.nerdtree
      vimPlugins.ctrlp-vim
      vimPlugins.undotree
      vimPlugins.vim-better-whitespace
      vimPlugins.markdown-preview-nvim
      vimPlugins.ale
    ];
    customRC = ''
      lua dofile("${../config/nvim/init.lua}")
    '';
  };
}
