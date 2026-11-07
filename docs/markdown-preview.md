# Static Markdown preview

The `markdown-preview` flake output builds `devchain-markdown`, a small OCaml
program using `ocamlPackages.cmarkit` from the existing
`github:NixOS/nixpkgs/nixos-26.05` input. No extra package registry or flake input
is used, and `flake.lock` is unchanged.

## Provenance and verification

- Locked nixpkgs revision: `08d3a97586f6b6343b3b5e799980773629432610`.
- Cmarkit: **0.3.0**, source
  `https://erratique.ch/software/cmarkit/releases/cmarkit-0.3.0.tbz`, with nixpkgs'
  fixed hash `sha256-RouM5iU7VeTT0+4yhBgdEmxROeP/X31iqDjd1VI7z5c=`.
  The downloaded archive's hash was recomputed and matched this pin.
- [Pinned package definition](https://github.com/NixOS/nixpkgs/blob/08d3a97586f6b6343b3b5e799980773629432610/pkgs/development/ocaml-modules/cmarkit/default.nix).
- [Pinned safe-renderer API](https://github.com/dbuenzli/cmarkit/blob/v0.3.0/src/cmarkit_html.mli)
  and [upstream documentation](https://erratique.ch/software/cmarkit).

Verification here means pinned source integrity, source inspection of the safe
renderer, and repeatable regression checks. **Cmarkit is not claimed to be
formally verified**, comprehensively audited, or a general-purpose HTML
sanitizer. Its upstream documentation explicitly distinguishes safe rendering
from sanitizing arbitrary HTML. OCaml's implementation language alone is not a
security proof.

The wrapper always uses `~safe:true` and `~backend_blocks:false`; it exposes no
option to turn these off. CommonMark and Cmarkit's table/task/strikethrough
extensions are supported. Raw HTML and executable diagram/math integrations are
not supported. A fixed page header blocks scripts, frames, forms, and automatic
resource loading, including remote and local images. Safe ordinary links remain
clickable: following a link leaves the preview's protection context.

## Editor behavior

`:MarkdownPreview` passes only the current Markdown buffer over stdin to the
immutable packaged renderer path. It does not save the source, enumerate other
buffers, read linked files, resolve images, start a listener, or download assets.
The result is a `0600` file inside a fresh `0700` temporary directory. The browser
opens a `file:` URI; there is no HTTP or editor RPC endpoint.

Repeated preview commands regenerate the snapshot. Stop/toggle, buffer wipe and
normal editor exit delete generated files. Stop cannot close browser tabs or
erase data already retained by the browser. A process crash can leave a private
temporary snapshot behind. As with any editor file, the same OS account and root
can read it; this is not isolation from programs running as the user.

The old JavaScript preview plugin and its Git submodule are removed from this
release. Previously initialized copies in other checkouts are not deleted or
patched. No change activates or restarts a running editor or ASUS configuration.

## Standalone use

```sh
nix run .#markdown-preview < document.md > preview.html
```

The renderer reads stdin and writes a complete HTML document to stdout. Unlike
the editor integration, shell redirection does not create private temporary
files or clean up: set a restrictive umask and delete the output when done. It
does not launch a browser.

## Checks

`nix flake check` includes `checks.<system>.markdown-preview`, which exercises:

- CommonMark, Unicode, code escaping and table rendering;
- suppression of raw HTML and unsafe link schemes, with no unsafe-mode option;
- the static page's restrictive content policy;
- headless Neovim rendering of unsaved text without exposing another buffer;
- private file/directory permissions, refresh, stop/toggle and cleanup.
- absence of the old preview plugin and Node.js from the editor runtime closure.

Native Apple Silicon macOS and ASUS x86_64 Linux both pass all **11 preview
checks** and the full **29-test suite**, including the attached-terminal tmux
test. Flake outputs also evaluate for ARM64 Linux.

These are offline parser/editor tests with a stubbed browser opener, not browser
penetration tests or a claim of universal XSS protection. Browser visual rendering
and OS opener behavior are not covered. ARM64 Linux remains evaluation-only
unless tested on a native builder.
