# Discord

Desktop client for the Discord chat platform.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Discord for this user |
| `package` | package | `pkgs.discord` | The Discord package to use |
| `autostart` | bool | false | Automatically start Discord on login |
| `extraPackages` | list of package | [ ] | Extra packages or plugins |
| `theme` | string | "dark" | Discord theme (if you have a theme loader installed) |

## Usage

```nix
my.programs.discord.enable = true;
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

- The `DISCORD_THEME` environment variable is set to the value of `theme`.
- Autostart installs a `.desktop` file to `~/.config/autostart/`.
