# =============================================================================
# lib/schemes/default.nix — the scheme catalog
# =============================================================================
# Takes NO arguments and auto-discovers every sibling `*.nix` file (except this
# one) into `{ <filename-without-extension> = <scheme attrset>; }`.
#
# This is what makes the catalog modular: dropping `lib/schemes/nord.nix` into
# this directory is the entire procedure for adding a theme. There is no
# registry to edit, no import list, and no option declaration — the flake
# picks it up on the next evaluation.
#
# A scheme file is a plain attrset. Only `base00`-`base0F` are load-bearing;
# everything semantic is derived centrally in `lib/theming.nix`, so a scheme
# author never has to think about role names.
#
#   {
#     name     = "Nord";        # human-readable label  (optional, defaults to slug)
#     slug     = "nord";        # kebab id             (optional, defaults to key)
#     family   = "nord";        # grouping for UIs     (optional)
#     variant  = "dark";        # fine-grained variant (optional)
#     polarity = "dark";        # "dark" | "light"     (optional, derived from base00)
#     base00   = "#2e3440";     # ... through base0F
#   }
# =============================================================================

let
  # Path literals resolve relative to the file containing them, so `./.` is
  # this directory. Guard the length before slicing so a stray short filename
  # cannot produce a negative substring start.
  isSchemeFile =
    name:
    let len = builtins.stringLength name;
    in name != "default.nix" && len > 4 && builtins.substring (len - 4) 4 name == ".nix";

  fileNames = builtins.filter isSchemeFile (builtins.attrNames (builtins.readDir ./.));
in
builtins.listToAttrs (
  map
    (file: {
      name = builtins.substring 0 (builtins.stringLength file - 4) file;
      # `./.${file}` silently loses the separating slash (it stringifies to
      # `./.catppuccin-mocha.nix` -> ".../schemescatppuccin-mocha.nix"), so the
      # directory and the filename are joined explicitly instead.
      value = import (./. + "/${file}");
    })
    fileNames
)
