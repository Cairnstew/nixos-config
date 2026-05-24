# WSL Window Manager

Xpra-based window manager for WSL2 with WSLg support.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.wsl-wm.enable` | `false` | Enable WSL window manager |
| `my.services.wsl-wm.windowManager` | `"i3"` | WM binary |
| `my.services.wsl-wm.display` | `":1"` | X display number |
| `my.services.wsl-wm.xpraArgs` | `[]` | Extra xpra arguments |
| `my.services.wsl-wm.extraPackages` | `[]` | Extra packages |

## Usage

```nix
my.services.wsl-wm.enable = true;
my.services.wsl-wm.windowManager = "i3";
```
