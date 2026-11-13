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
    "my.programs.superfile.theme"
    "my.programs.superfile.settings"
    "my.programs.superfile.themes"
    "my.programs.superfile.previews"
  ];
  expects = [
    "flake.config.preferences"
  ];
  complexity = "medium";
  tested = true;
  # A theme TOML generated from my.theming.colors and selected via
  # settings.theme; user themes in my.programs.superfile.themes still win.
  theme = {
    kind = "tui";
    mechanism = "generated";
    file = "theme.nix";
  };
  homepage = "https://superfile.dev";
  maintainer = "seanc";
}
