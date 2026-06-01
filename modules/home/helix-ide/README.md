# Helix IDE

Helix editor + Zellij terminal multiplexer IDE environment. Enables both tools with sensible defaults and provides an `ide` shell alias to launch Zellij with Helix as the default pane.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.helix-ide.enable` | `false` | Enable Helix + Zellij IDE environment |
| `my.programs.helix-ide.inlineDiagnostics` | `"hint"` | Display diagnostics inline. Options: `"none"`, `"hint"`, or `"warning"` |
| `my.programs.helix-ide.inlayHints` | `true` | Show inline type hints and parameter names from the LSP |
| `my.programs.helix-ide.relativeLines` | `true` | Use relative line numbering for faster modal vertical motions |
| `my.programs.helix-ide.rainbowRulers` | `true` | Add modern visual color column indicators for clean indentation |

## Usage

```nix
my.programs.helix-ide.enable = true;
```

Then run `ide` from your terminal.

## Notes

- Helix theme is set to `catppuccin_mocha` with mouse and bufferline enabled.
- Zellij `mouse_mode` is enabled.
- The `ide` shell alias launches Zellij with the IDE layout, placing Helix as the default pane.
