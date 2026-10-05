# Theming

The NixOS-side entry point to the shared colour infrastructure. This module has
no side effects: it exposes the palette resolved by
[`lib/theming.nix`](../../../lib/theming.nix) as `my.theming.*`, so modules
never have to thread `flake` through their arguments.

See [`lib/README.md`](../../../lib/README.md) for the full documentation.

## Options

All options are read-only. There is deliberately **no `enable`**: the palette is
inert data, and gating it would only push `attribute 'accent' missing` errors
into consumer modules. Theming *behaviour* is gated by
`my.theming.stylix.enable`.

| Option | Type | Description |
|---|---|---|
| `my.theming.colors` | attrs | Resolved palette — roles, `terminal`, `base16` |
| `my.theming.lib` | raw | Pure colour maths (`my.theming.lib.color.*`) |
| `my.theming.scheme` | string | Active scheme slug, e.g. `catppuccin-mocha` |
| `my.theming.polarity` | `dark`/`light` | Polarity of the active scheme |
| `my.theming.schemes` | list of string | Every available scheme |

## Usage

```nix
{
  programs.rofi = {
    enable = true;
    theme = {
      background = config.my.theming.colors.background;
      foreground = config.my.theming.colors.foreground;
      selected = config.my.theming.colors.accent;
    };
  };

  # Colour maths without importing anything
  systemd.user.services.myAlert = {
    description = ''
      Accent ${config.my.theming.colors.accent} on
      ${config.my.theming.colors.background}
      (${builtins.toString config.my.theming.lib.color.contrast
        config.my.theming.colors.background
        config.my.theming.colors.accent}:1)
    '';
  };
}
```

To change the palette, edit `theming.scheme` in the repo-root `config.nix` —
not this module.

## Tests

`tests.nix` asserts, on every host build:

- `theming.scheme` names a real scheme (no silent fallback)
- every documented role is present
- all 16 ANSI terminal slots are present
- `theming.overrides` values are valid hex
- body text clears WCAG AA (4.5:1) against the background
- the terminal background tracks the resolved `background`

## Related Modules

- **Consumed by** [`modules/nixos/stylix`](../stylix/) — feeds
  `my.theming.colors.base16` to stylix
- **Twinned by** [`modules/home/theming`](../../home/theming/) — same option
  surface for Home Manager modules
- **Schema** [`modules/flake-parts/theming.nix`](../../flake-parts/theming.nix)
- **Resolution** [`lib/theming.nix`](../../../lib/theming.nix)
- **Schemes** [`lib/schemes/`](../../../lib/schemes/)
- **Imported by** [`modules/nixos/common.nix`](../common.nix)