# modules/home/superfile.nix
# superfile (TUI file manager) — installed on PATH and given a Nix-managed
# `config.toml`. The binary is `superfile`; upstream's install script also
# creates an `spf` symlink, which the nixpkgs derivation does not.
#
# The config is a read-only store symlink. That is safe: superfile's
# `writeConfigFile` only writes when the file is absent, so it never tries to
# rewrite ours (`--fix-config-file` would, so don't run it against this file).
{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.superfile;

  toml = pkgs.formats.toml { };

  # Keys we always set, overridable through `settings`.
  #   ignore_missing_fields — a partial config must not warn on every launch
  #     about the ~60 keys we deliberately leave at their compiled defaults.
  #   code_previewer = "bat" — the built-in chroma previewer is weaker for
  #     markdown/prose; bat needs to be on PATH (see extraPackages).
  #   show_image_preview — gates the PDF/video thumbnail path entirely
  #     (internal/ui/preview/render.go returns a "disabled" string when false).
  baseSettings = {
    ignore_missing_fields = true;
    code_previewer = "bat";
    show_image_preview = true;
    default_open_file_preview = true;
  };
in
{
  options.my.programs.superfile = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable superfile and manage its config.toml.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.superfile;
      defaultText = lib.literalExpression "pkgs.superfile";
      description = "superfile package to install.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = lib.literalExpression ''
        {
          theme = "catppuccin-mocha";
          file_preview_width = 6;
          enable_file_preview_border = true;
          open_with = {
            pdf = "zathura";
          };
        }
      '';
      description = ''
        Extra `config.toml` keys, merged over the defaults below (yours win).
        Everything omitted keeps the value compiled into superfile.
        `open_with` entries are launched detached with no TTY, so they must be
        GUI programs — `open_with.md = "glow"` would exit invisibly.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        bat
        poppler-utils
      ];
      defaultText = lib.literalExpression "with pkgs; [ bat poppler-utils ]";
      description = ''
        Runtime helpers placed on PATH for superfile:
        - bat: markdown/source preview highlighting (`code_previewer = "bat"`)
        - poppler_utils: `pdftoppm`, which renders a PDF's first page as the
          preview thumbnail. Without it the preview panel reports a thumbnail
          generation error.
        Add `ffmpeg` here for video thumbnails, `exiftool` for
        `settings.metadata = true`, and `zoxide` for the `z` jump.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ cfg.extraPackages;

    xdg.configFile."superfile/config.toml".source = toml.generate "superfile-config.toml" (lib.recursiveUpdate baseSettings cfg.settings);
  };
}
