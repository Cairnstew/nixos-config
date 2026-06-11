# zed-editor

Zed editor module for Home Manager. Configures `programs.zed-editor` with
typed options for common settings.

## Options

All options live under `my.programs.zed-editor`.

### Core
- `enable` — Enable Zed
- `package` — Zed package to use
- `defaultEditor` — Set EDITOR/VISUAL to zed
- `extensions` — Extensions to install on startup
- `mutableUserSettings/Keymaps/Tasks/Debug` — Whether Zed can overwrite Nix-managed configs

### Appearance
- `theme` — Theme name or `{ dark, light, mode }` attrset
- `customThemes` — Custom theme definitions (auto-generates Catppuccin Mocha from me.colorScheme)
- `fontFamily` / `fontSize` — Base font settings
- `uiFontSize` / `bufferFontSize` — UI/buffer-specific font sizes
- `terminalFontFamily` / `terminalFontSize` — Terminal panel font settings

### Editor
- `vimMode`, `relativeLineNumbers`, `tabSize`, `softWrap`
- `formatOnSave`, `autosave`, `cursorShape`
- `inlayHints`, `indentGuides`, `showWhitespaces`
- `confirmQuit`, `restoreSessions`, `scrollPastEnd`

### Git
- `git.gutter` — Which files show git gutter indicators
- `git.inlineBlame` / `git.inlineBlameDelay` — Inline blame annotations

### Terminal
- `terminal.alternateScroll`, `terminal.blinking`, `terminal.copyOnSelect`
- `terminal.shell` — Custom shell path
- `terminal.env` — Extra environment variables

### Pass-through
- `extraSettings` — Raw attrs merged on top of computed settings
- `userKeymaps`, `userTasks`, `userDebug` — Raw JSON config files

## Example usage

```nix
my.programs.zed-editor = {
  enable = true;
  vimMode = true;
  fontSize = 14;
  extensions = [ "nix" "rust" "toml" "yaml" ];
  git.inlineBlame = true;
};
```
