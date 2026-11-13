# Theming (Home Manager)

Home Manager mirror of [`modules/nixos/theming`](../../nixos/theming/), so a
home module reads the palette the same way a NixOS module does:

```nix
my.theming.colors.accent
```

Every module in `modules/home/` is added as a shared module by
`modules/nixos/homeManager/config.nix` (`builtins.attrValues self.homeModules`),
so this lands on every user of every host with no per-host wiring.

See [`lib/README.md`](../../../lib/README.md) for the full documentation.

## Options

All read-only; there is no `enable`, for the same reason as the NixOS twin.

| Option | Type | Description |
|---|---|---|
| `my.theming.colors` | attrs | Resolved palette — roles, `terminal`, `base16` |
| `my.theming.lib` | raw | Pure colour maths |
| `my.theming.scheme` | string | Active scheme slug |
| `my.theming.schemeUnderscored` | string | Slug with `-` → `_`, for helix |
| `my.theming.polarity` | `dark`/`light` | Polarity of the active scheme |

## Usage

```nix
{
  programs.lazygit.settings.gui.theme = {
    lightTheme = false;
    activeBorderColor = [ config.my.theming.colors.accent "bold" ];
    inactiveBorderColor = [ config.my.theming.colors.foregroundMuted ];
  };

  programs.helix.settings.theme = config.my.theming.schemeUnderscored;
}
```

## Standalone use

`flake` is defaulted, so this module also evaluates in a Home Manager
configuration with no flake input: it falls back to resolving the catalog
default from `lib/theming.nix` directly. The option surface never disappears.

## Theming an application

Per-application theming does not live here. A module with a GUI/TUI/Web surface
ships its own `theme.nix`, declares `my.<namespace>.theme` with
[`lib/theme.nix`](../../../lib/theme.nix)'s `mkAppTheme`, and applies
`config.my.theming.colors` to that application's own format. This module stays a
read-only palette mirror on purpose.

See [`modules/AGENT.md` §2.2](../../AGENT.md) for the contract and
[`docs/decisions/2026-11-13-theme-nix.md`](../../../docs/decisions/2026-11-13-theme-nix.md)
for the rollout plan.

## Themed applications

| App | Option | Surface |
|---|---|---|
| zed | `my.programs.zed-editor.theme` | generated theme extension |
| ghostty | `my.programs.ghostty.theme` | generated `themes.<slug>` |
| helix | `my.programs.helix-ide.theme` | generated Helix TOML theme |
| qutebrowser | `my.programs.qutebrowser.theme` | generated `c.colors.*` (`theme.py`) |
| vscode | `my.programs.vscode.theme` | workbench + token colour customizations |
| opencode | `my.programs.opencode.theme` | `themes.<slug>` (V1 `defs` shape) |
| spotify | `my.programs.spotify.theme` | spotatui `theme:` block |
| firefox | `my.programs.firefox.theme` | opt-in `userChrome`/`userContent` |
| thunderbird | `my.programs.thunderbird.theme` | opt-in `userChrome` |


## Tests

`tests.nix` asserts the palette is complete (roles and all 16 ANSI slots), the
slug is non-empty, the scheme's declared `polarity` agrees with its own
background's luminance, and body text clears WCAG AA.

## Related Modules

- **Twinned by** [`modules/nixos/theming`](../../nixos/theming/)
- **Resolution** [`lib/theming.nix`](../../../lib/theming.nix)
- **Schemes** [`lib/schemes/`](../../../lib/schemes/)