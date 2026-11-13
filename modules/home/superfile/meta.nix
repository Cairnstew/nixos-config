{
  name = "superfile";
  description = "superfile TUI file manager: Nix-managed config.toml, theme files, and PATH-derived preview/plugin helpers";
  category = "programs";
  tags = [
    "tui"
    "file-manager"
    "superfile"
    "preview"
  ];
  provides = [
    "my.programs.superfile"
    "my.programs.superfile.settings"
    "my.programs.superfile.themes"
    "my.programs.superfile.previews"
  ];
  expects = [
    "flake.config.preferences"
  ];
  complexity = "medium";
  tested = true;
  theme = {
    kind = "tui";
    mechanism = "none";
    reason = ''
      Theme TOML is written verbatim from my.programs.superfile.themes and
      superfile ships 21 embedded themes; generating one from my.theming.colors
      is deferred until docs/decisions/2026-11-13-theme-nix.md lands, so this
      module holds no colour code.
    '';
  };
  homepage = "https://superfile.dev";
  maintainer = "seanc";
}
