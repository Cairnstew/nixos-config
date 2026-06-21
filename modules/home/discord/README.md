# Discord

Desktop client for the Discord chat platform. Supports both the standard GUI client and [Endcord](https://github.com/sparklost/endcord) TUI client.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Discord for this user |
| `package` | package | `pkgs.discord` | The Discord package to use |
| `tui` | bool | false | Use Endcord TUI client instead of the GUI Discord desktop app |
| `autostart` | bool | false | Automatically start on login |
| `extraPackages` | list of package | [ ] | Extra packages or plugins |
| `theme` | string | "dark" | Discord theme (only applies to GUI Discord, ignored in TUI mode) |

## Usage

### Standard GUI Discord

```nix
my.programs.discord.enable = true;
```

### With Endcord TUI

```nix
my.programs.discord = {
  enable = true;
  tui = true;
  autostart = true;
};
```

### With autostart and custom theme

```nix
my.programs.discord = {
  enable = true;
  autostart = true;
  theme = "amethyst";
};
```

## Notes

- The `DISCORD_THEME` environment variable is only set when using the GUI Discord client (not in TUI mode).
- Endcord stores its configuration in `~/.config/endcord/`.
