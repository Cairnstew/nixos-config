# Home Manager Integration

Wires all home-manager modules into a NixOS system user.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.homeManager.enable` | `true` | Enable Home Manager |
| `my.homeManager.extraModules` | `[]` | Extra HM modules |
| `my.homeManager.extraConfig` | `{}` | Extra HM config |

## Usage

```nix
my.homeManager.enable = true;
my.homeManager.extraConfig.my.programs.firefox.enable = true;
```
