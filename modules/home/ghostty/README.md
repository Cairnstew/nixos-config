# Ghostty

GPU-accelerated terminal emulator with custom themes, keybindings, and settings.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | terminal default | Enable Ghostty terminal emulator |
| `enableSystemd` | bool | true | Enable systemd integration |
| `package` | package | `pkgs.ghostty` | Ghostty package to use |
| `fontSize` | int | preferences value | Font size |
| `windowWidth` | int | 100 | Default window width in columns |
| `windowHeight` | int | 30 | Default window height in rows |
| `theme.enable` | bool | true | Generate and activate a theme from the shared palette |
| `theme.name` | string | active scheme slug | Ghostty theme to activate |
| `theme.overrides` | attrs | { } | Per-app colour overrides |
| `theme.customThemes` | attrset | { } | Extra theme definitions (same name wins) |
| `gtkTitlebar` | bool | true | Enable GTK titlebar |
| `clearDefaultKeybinds` | bool | true | Clear default keybindings |
| `keybindings` | list of string | see defaults | Custom keybindings |
| `additionalKeybindings` | list of string | [ ] | Additional keybindings |
| `extraSettings` | attrset | { } | Additional settings |

## Usage

```nix
my.programs.ghostty.enable = true;
```

### With custom settings

```nix
my.programs.ghostty = {
  enable = true;
  fontSize = 14;
  theme = {
    # defaults to the generated theme for the active scheme
    overrides.accent = "#ff0055";
  };
  extraSettings = {
    cursor-style = "bar";
    cursor-style-blink = true;
  };
};
```

## Notes

- The default `theme` is generated from `my.theming.colors`, so switching
  `theming.scheme` re-themes the terminal. Stylix's ghostty target is disabled
  while this theme is active (one owner per app).
- Default `fontSize` uses `preferences.terminalFontSize`.
- The `font-family` is set from `preferences.terminalFont`.
