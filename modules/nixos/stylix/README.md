# Stylix

Auto-themes apps via the Stylix base16 framework.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.theming.stylix.enable` | bool | false | Enable Stylix theming |
| `my.theming.stylix.polarity` | `"dark"` or `"light"` | active scheme polarity | Theme polarity |
| `my.theming.stylix.wallpaper` | null or path | null | Wallpaper image path |

## Usage

```nix
my.theming.stylix = {
  enable = true;
  polarity = "dark";
  wallpaper = ./wallpapers/catppuccin-mocha.png;
};
```

## Dependencies

- **NixOS modules**: stylix, qt
- **Flake inputs**: stylix

## Notes

- Reads `my.theming.colors.base16` (from `theming.scheme` in the repo-root config.nix); the hashless conversion lives in `lib/theming.nix`.
- Fonts default to JetBrainsMono Nerd Font (monospace), Inter (sans-serif), Noto Color Emoji.
- GNOME target is enabled when `my.desktop.gnome.enable` is set.
- Overrides `qt.platformTheme` to `"adwaita"` (upstream default `"gnome"` is deprecated).

## Related Modules

- **Reads** [`modules/nixos/theming`](../theming/) — the palette (`my.theming.colors`)
- **Schemes** [`lib/schemes/`](../../../lib/schemes/)

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
