# modules/home/superfile/options.nix
{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.superfile;
  # The repo-wide editor preference (config.nix: `preferences.editor`).
  preferredEditor = flake.config.preferences.editor or "";
in
{
  options.my.programs.superfile = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install superfile and manage its `config.toml` and theme files.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.superfile;
      defaultText = lib.literalExpression "pkgs.superfile";
      description = ''
        superfile package. Its binary is `superfile` — upstream's installer adds
        an `spf` symlink that the nixpkgs derivation does not.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = lib.literalExpression ''
        {
          theme = "catppuccin-mocha";
          file_preview_width = 6;
          file_panel_extra_columns = 3;
          # Runs detached with no TTY and no arguments, so GUI programs only.
          open_with = {
            md = "obsidian";
            pdf = "zathura";
          };
        }
      '';
      description = ''
        Extra `config.toml` keys, merged over the module defaults
        (`ignore_missing_fields`, `code_previewer = "bat"`, image preview,
        `auto_check_update = false`, `dir_editor`). Yours win.

        Keys omitted here keep the value compiled into superfile, so a partial
        config is normal — `ignore_missing_fields` silences the warnings.

        `open_with` is executed as `<command> <path>`, detached from the
        terminal, so the value must be a bare executable name of a **GUI**
        program: `glow`/`pandoc` would exit invisibly. TOML requires
        `[open_with]` to be the last table in the file; the generator places it
        after the scalars, so do not add further tables alongside it.
      '';
    };

    themes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      example = lib.literalExpression ''
        {
          "my-palette" = {
            code_syntax_highlight = "catppuccin-mocha";
            full_screen_fg = config.my.theming.colors.foreground;
            full_screen_bg = config.my.theming.colors.background;
            gradient_color = [
              config.my.theming.colors.accent
              config.my.theming.colors.accentAlt
            ];
          };
        }
      '';
      description = ''
        Extra theme files, written to `$XDG_CONFIG_HOME/superfile/theme/<name>.toml`.
        Select one with `settings.theme = "<name>"`. Names are restricted to
        `[A-Za-z0-9._-]` (asserted) because they become filenames.
        superfile ships 21 embedded themes — this option is for anything the
        nixpkgs package cannot provide.
      '';
    };

    editor = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Editor for files (`e`). Empty means upstream behaviour: `$EDITOR`, then
        `nano`. Set this only if you want to override `$EDITOR`.
      '';
    };

    dirEditor = lib.mkOption {
      type = lib.types.str;
      default = preferredEditor;
      defaultText = lib.literalExpression "flake.config.preferences.editor";
      example = "hx";
      description = ''
        Editor for directories (`E`). Upstream's compiled default is `vi`, which
        is absent on a NixOS host with no vim installed, so this defaults to the
        repo-wide `preferences.editor` instead.
      '';
    };

    previews = {
      pdf = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install `poppler-utils` so a `.pdf` previews as a rendered first page.
          superfile shells out to `pdftoppm`; without it the preview panel shows
          a thumbnail-generation error. Only effective while
          `show_image_preview` is true, and only on a terminal speaking the
          kitty graphics protocol (Ghostty, kitty, WezTerm — sixel and iTerm2
          fall back to ANSI blocks).
        '';
      };

      video = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Install `ffmpeg` so videos preview as a frame thumbnail. Off by
          default: it is a large closure for a preview.
        '';
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ unzip p7zip ]";
      description = ''
        Additional packages on PATH. Note that superfile's own helper needs are
        derived from `settings` and `previews` — `bat` for
        `code_previewer = "bat"`, `poppler-utils` for PDF, `ffmpeg` for video,
        and `exiftool`/`zoxide` for `settings.metadata`/`settings.zoxide_support`.
        No need to repeat them here.
      '';
    };
  };
}
