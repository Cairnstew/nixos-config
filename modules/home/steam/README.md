# Steam

Steam gaming platform configured via Home Manager. Installs `steam`, `steam-run`,
and `steamcmd`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.steam.enable` | `false` | Enable Steam and related packages |
| `my.programs.steam.extraPackages` | `[]` | Extra Steam-related packages |
| `my.programs.steam.extraCompatPaths` | `null` | Extra Proton compatibility tool paths |

## Usage

```nix
my.programs.steam = {
  enable = true;
  extraCompatPaths = "$HOME/.steam/root/compatibilitytools.d";
};
```

## Notes

- Enables `nixpkgs.config.allowUnfree` when enabled.
- `STEAM_EXTRA_COMPAT_TOOLS_PATHS` is set as a session variable when
  `extraCompatPaths` is non-null.
