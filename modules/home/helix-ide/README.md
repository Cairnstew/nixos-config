# Helix IDE

Helix editor + Zellij terminal multiplexer IDE environment. Enables both tools with sensible defaults and provides an `ide` shell alias to launch Zellij with Helix as the default pane.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.helix-ide.enable` | `false` | Enable Helix + Zellij IDE environment |

## Usage

```nix
my.programs.helix-ide.enable = true;
```

Then run `ide` from your terminal.

## Notes

- Helix theme is set to `catppuccin_mocha` with mouse and bufferline enabled.
- Zellij `mouse_mode` is enabled.
- The `ide` shell alias launches Zellij with the IDE layout, placing Helix as the default pane.
