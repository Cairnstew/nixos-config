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
| `theme` | string | dark mode dependent | Theme name |
| `gtkTitlebar` | bool | true | Enable GTK titlebar |
| `clearDefaultKeybinds` | bool | true | Clear default keybindings |
| `keybindings` | list of string | see defaults | Custom keybindings |
| `additionalKeybindings` | list of string | [ ] | Additional keybindings |
| `customThemes` | attrset | catppuccin-mocha | Custom theme definitions |
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
  theme = "catppuccin-mocha";
  extraSettings = {
    cursor-style = "bar";
    cursor-style-blink = true;
  };
};
```

## Notes

- Default `theme` depends on `preferences.darkMode` from flake config.
- Default `fontSize` uses `preferences.terminalFontSize`.
- The `font-family` is set from `preferences.terminalFont`.
