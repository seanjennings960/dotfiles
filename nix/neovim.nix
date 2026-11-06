{
  lib,
  neovim,
  vimPlugins,
  diffutils,
  ruff,
  markdownPreview,
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
      vimPlugins.ale
    ];
    customRC = ''
      lua dofile("${../config/nvim/init.lua}")
      lua vim.g.devchain_markdown_renderer = "${markdownPreview}/bin/devchain-markdown"
      lua dofile("${../config/nvim/markdown-preview.lua}")
    '';
  };
}
