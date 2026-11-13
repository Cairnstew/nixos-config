# modules/home/superfile/merge.nix
# Pure helper: the effective `config.toml` contents. Imported by config.nix
# (which writes the file) and packages.nix (which installs the helpers those
# settings need), so the config and PATH can never drift apart.
{ lib, cfg }:
let
  # Defaults chosen so that a bare `enable = true` is usable on NixOS:
  #   ignore_missing_fields — this module writes ~8 of superfile's 126 keys.
  #   code_previewer = "bat" — the bundled chroma previewer is weaker for
  #     markdown/prose; packages.nix installs bat when this is "bat".
  #   show_image_preview — gates the PDF/video thumbnail path (render.go).
  #   auto_check_update = false — nixpkgs owns the version; upstream would
  #     query GitHub once a day on exit for an update it cannot install.
  base = {
    ignore_missing_fields = true;
    code_previewer = "bat";
    show_image_preview = true;
    default_open_file_preview = true;
    auto_check_update = false;
  };

  # Empty `editor` means "use $EDITOR, then nano" upstream, so only set it when
  # the user picked one explicitly. `dir_editor` is always set: upstream's
  # compiled default is `vi`, which does not exist on a stock NixOS host.
  editor = lib.optionalAttrs (cfg.editor != "") { editor = cfg.editor; };
in
lib.recursiveUpdate base (editor // { dir_editor = cfg.dirEditor; } // cfg.settings)
