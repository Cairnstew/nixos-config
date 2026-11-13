# modules/home/superfile/tests.nix
# L0 assertions only (no service). They mirror upstream's own config validation
# (src/internal/common/load_config.go), which merely logs a warning — a typo
# there costs you a silently ignored setting, not an error.
{ config, lib, ... }:
let
  cfg = config.my.programs.superfile;
  s = import ./merge.nix { inherit lib cfg; };

  isIntIn = lo: hi: v: builtins.isInt v && v >= lo && v <= hi;

  validSections = [
    "home"
    "pinned"
    "disks"
  ];

  badSections = builtins.filter (x: !(builtins.elem x validSections)) (s.sidebar_sections or [ ]);
  badOpenWith = lib.filterAttrs (_: v: !(builtins.isString v)) (s.open_with or { });
  badThemeNames = builtins.filter (n: builtins.match "[A-Za-z0-9._-]+" n == null) (builtins.attrNames cfg.themes);
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.elem (s.code_previewer or "") [ "" "bat" ];
        message = ''
          my.programs.superfile.settings.code_previewer must be "" (bundled chroma)
          or "bat" — superfile ignores anything else, leaving no previewer.
        '';
      }
      {
        assertion = isIntIn 0 4 (s.default_sort_type or 0);
        message = "my.programs.superfile.settings.default_sort_type must be 0-4 (name/size/mtime/type/natural).";
      }
      {
        assertion = (s.file_preview_width or 0) == 0 || isIntIn 2 10 (s.file_preview_width or 0);
        message = "my.programs.superfile.settings.file_preview_width must be 0 (same as panel) or 2-10 (1/n of width); 1 is not accepted.";
      }
      {
        assertion = (s.sidebar_width or 20) == 0 || isIntIn 5 20 (s.sidebar_width or 20);
        message = "my.programs.superfile.settings.sidebar_width must be 0 (hidden) or 5-20; 1-4 is not accepted.";
      }
      {
        assertion = isIntIn 25 100 (s.file_panel_name_percent or 50);
        message = "my.programs.superfile.settings.file_panel_name_percent must be 25-100.";
      }
      {
        assertion = isIntIn 0 3 (s.file_panel_extra_columns or 0);
        message = "my.programs.superfile.settings.file_panel_extra_columns must be 0-3 (0 disables the extra columns).";
      }
      {
        assertion = badSections == [ ];
        message = "my.programs.superfile.settings.sidebar_sections contains unknown entries: ${lib.concatStringsSep ", " badSections} (valid: home, pinned, disks).";
      }
      {
        assertion = badOpenWith == { };
        message = "my.programs.superfile.settings.open_with values must be strings (bare executable names): ${lib.concatStringsSep ", " (builtins.attrNames badOpenWith)}.";
      }
      {
        assertion = badThemeNames == [ ];
        message = "my.programs.superfile.themes names must match [A-Za-z0-9._-] (they become filenames): ${lib.concatStringsSep ", " badThemeNames}.";
      }
      {
        assertion = cfg.dirEditor != "";
        message = ''
          my.programs.superfile.dirEditor must not be empty: upstream then falls
          back to `vi`, which a stock NixOS host does not provide, so `E` (open
          directory with editor) would only log an error.
        '';
      }
      # ── Theming (theme.nix) ──────────────────────────────────────────────
      {
        assertion = !cfg.theme.enable || (cfg.themes ? ${cfg.theme.name});
        message = "superfile theme: the generated theme was not added to my.programs.superfile.themes.";
      }
      {
        assertion = !cfg.theme.enable || (cfg.settings.theme or "") == cfg.theme.name;
        message = "superfile theme: settings.theme was not pointed at the generated theme.";
      }
      {
        assertion = !cfg.theme.enable || (cfg.theme.settings ? file_panel_bg && cfg.theme.settings ? gradient_color);
        message = "superfile theme: the generated theme table is missing file_panel_bg/gradient_color.";
      }
    ];
  };
}
