# =============================================================================
# copy-md-as-html.nix — Markdown to HTML Clipboard Converter
# =============================================================================
# Purpose: Converts a Markdown file to HTML and copies it to the clipboard
#          as rich text (text/html), useful for pasting into Gmail, Docs, etc.
#
# Not in nixpkgs: Simple workflow utility combining pandoc + wl-clipboard.
#
# Usage: copy-md-as-html <file.md>
# Prerequisites: Wayland session (uses wl-clipboard).
# =============================================================================

{ writeShellApplication, wl-clipboard, pandoc, ... }:

writeShellApplication {
  name = "copy-md-as-html";
  meta = {
    description = "Convert Markdown to HTML and copy to clipboard";
    longDescription = ''
      Converts a Markdown file to HTML using pandoc and copies the result
      to the clipboard as rich text (text/html MIME type). Useful for
      pasting formatted content into web-based email clients, Google Docs,
      or other rich text editors.
      
      Usage: copy-md-as-html <file.md>
      
      Note: Requires Wayland (uses wl-clipboard). For X11, use xclip instead.
    '';
    homepage = "https://pandoc.org/";
    license = "MIT";
    mainProgram = "copy-md-as-html";
  };
  runtimeInputs = [ wl-clipboard pandoc ];
  text = ''
    set -x
    pandoc "$1" -t html | wl-copy -t text/html
    echo "Copied HTML to clipboard"
  '';
}
