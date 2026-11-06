{
  runCommand,
  python3Packages,
  markdownPreview,
  configuredNeovim,
  closureInfo,
}:

runCommand "devchain-markdown-preview-check"
  {
    nativeBuildInputs = [ python3Packages.pytest ];
    DOTFILES_TEST_MARKDOWN = "${markdownPreview}/bin/devchain-markdown";
    DOTFILES_TEST_NVIM = "${configuredNeovim}/bin/nvim";
    DOTFILES_TEST_PREVIEW_CLOSURE = "${
      closureInfo {
        rootPaths = [
          configuredNeovim
          markdownPreview
        ];
      }
    }/store-paths";
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    python -m pytest -p no:cacheprovider ${../tests/test_markdown_preview.py}
    touch "$out"
  ''
