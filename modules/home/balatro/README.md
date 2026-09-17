# Balatro

Balatro card game with optional multiplayer mod support.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.balatro.enable` | `false` | Enable Balatro support |
| `my.programs.balatro.multiplayer.enable` | `false` | Enable Balatro Multiplayer mod |
| `my.programs.balatro.multiplayer.launcher.version` | `"1.0.18"` | Launcher version |
| `my.programs.balatro.multiplayer.mod.version` | `"0.5.5"` | Mod version |

## Usage Example

```nix
my.programs.balatro = {
  enable = true;
  multiplayer = {
    enable = true;  # Default false — opt-in to multiplayer
  };
};
```

## Commands

When multiplayer is enabled, the following commands are available:

| Command | Description |
|---------|-------------|
| `balatro-mp-launcher` | Open the Balatro Multiplayer Launcher (manage versions, install deps) |
| `balatro-mp-install` | Install/reinstall the multiplayer mod files to the game directory |
| `balatro-mp` | Launch Balatro via Steam with the multiplayer mod |
| `balatro-find-install` | Find the Balatro game installation directory |

## Notes

- Requires Steam with Balatro installed (`my.programs.steam.enable = true`).
- The launcher is an Electron AppImage wrapped with `buildFHSEnv` for NixOS.
- Mod files are automatically deployed to the game's `Mods/` directory on
  `home-manager switch`.
- Upstream: [Balatro Multiplayer](https://balatromp.com/docs/getting-started/installation)
