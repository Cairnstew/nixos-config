# Satisfactory

Satisfactory game support with modding tools and dedicated server configuration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.satisfactory.enable` | `false` | Enable Satisfactory support |
| `my.programs.satisfactory.modding.enable` | `false` | Install ficsit-cli and SMM for mod management |
| `my.programs.satisfactory.dedicatedServer.enable` | `false` | Open firewall ports for dedicated server |
| `my.programs.satisfactory.dedicatedServer.gamePort` | `15777` | UDP game port |
| `my.programs.satisfactory.dedicatedServer.queryPort` | `15778` | UDP query port |
| `my.programs.satisfactory.dedicatedServer.beaconPort` | `15779` | UDP beacon port |

## Usage Example

```nix
my.programs.satisfactory = {
  enable = true;
  modding.enable = true;
  dedicatedServer = {
    enable = true;
    # ports are fine at defaults
  };
};
```

## Notes

- Satisfactory installs through Steam (App ID `526870`); it is installed into
  the Steam library folder that Steam picks, and **mods follow the game install**
  — ficsit-cli/SMM always write into the install's own
  `FactoryGame/Mods` folder, wherever that library lives.
- Mods are managed via `ficsit-cli` (CLI/TUI) or Satisfactory Mod Manager (GUI).
- See the [Satisfactory Modding Docs](https://docs.ficsit.app/satisfactory-modding/latest/index.html) for details.
- Requires `my.programs.steam.enable = true` (Steam with Proton support).
