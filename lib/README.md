# Theming infrastructure

One place decides what colour everything is. Three layers, each usable on its
own:

| Layer | File | Depends on | Used by |
|---|---|---|---|
| Colour maths | `color.nix` | `lib` only | anything |
| Schemes | `schemes/*.nix` | nothing | `theming.nix` |
| Resolution | `theming.nix` | `lib` only | modules, scripts, `flake.lib` |

```
lib/
├── color.nix          parse / luminance / contrast / mix / alpha
├── theming.nix        base16 -> semantic roles, terminal palette
├── schemes/           one file per scheme, auto-discovered
│   └── default.nix
└── README.md
```

## Reading the palette

Inside a NixOS module:

```nix
{ config, ... }:
{
  programs.rofi = {
    enable = true;
    theme = {
      background = config.my.theming.colors.background;
      foreground = config.my.theming.colors.foreground;
      selected  = config.my.theming.colors.accent;
    };
  };
}
```

Inside a Home Manager module: identical, via `my.theming.colors`.

Outside the module system:

```console
$ nix eval --impure --expr \
    '(builtins.getFlake (toString ./.))#lib.theming.mkColors { scheme = "nord"; }.accent'
"#81a1c1"
```

Or list what is available:

```console
$ nix eval --json .#lib.theming.schemeNames
["catppuccin-frappe","catppuccin-latte","catppuccin-macchiato",
 "catppuccin-mocha","dracula","gruvbox-dark","nord","tokyo-night"]
```

## Changing the theme

Edit one line in the repo-root `config.nix`:

```nix
theming.scheme = "nord";
```

To tweak individual colours without forking a scheme:

```nix
theming.overrides = {
  # Override a base16 slot; every role derived from it follows.
  base00 = "#000000";
  # Override one role; nothing else moves.
  accent = "#ff0055";
};
```

Later always wins: base overrides are applied first and roles re-derived from
them, then role overrides are applied on top.

## Adding a scheme

Drop one file into `lib/schemes/`. There is no registry to update —
`schemes/default.nix` reads the directory, and the module tests assert the new
scheme's slots are valid hex and that its declared `polarity` matches its own
background.

```nix
# lib/schemes/my-theme.nix
{
  name = "My Theme";     # optional, defaults to the slug
  slug = "my-theme";     # optional
  family = "mine";       # optional — groups light/dark counterparts
  variant = "dark";      # optional
  polarity = "dark";     # optional — derived from base00 if omitted
  base00 = "#101010";
  # ... through base0F
}
```

Only `base00`-`base0F` are required. Everything semantic is derived.

## What you get

`mkColors` returns more than the base16 slots:

- **Identity** — `slug`, `name`, `family`, `variant`, `polarity`, `isDark`
- **Surfaces** — `background`, `surface`, `backgroundPanel`,
  `backgroundElement`, `backgroundHover`, `backgroundSelected`
- **Text** — `foreground`, `foregroundMuted`, `foregroundSubtle`
- **Borders** — `border`, `borderSubtle`, `borderStrong`, `borderActive`
- **Status** — `accent`, `accentAlt`, `accentMuted`, `success`, `warning`,
  `error`, `info`
- **Interaction** — `cursor`, `selection`, `selectionText`
- **Diff** — `diffAdded`, `diffRemoved`, `diffModified`
- **Syntax** — `syntaxKeyword`, `syntaxFunction`, `syntaxString`,
  `syntaxNumber`, `syntaxType`, `syntaxComment`, `syntaxOperator`
- **`terminal`** — the 16 ANSI colours plus `cursor`, `selection`
- **`base16`** — the hashless palette stylix and base16 tooling expects
- **`onBackground`** — a text colour guaranteed legible on `background`

The role mapping is one table, in `theming.nix` (`deriveRoles`). Adding a role
is safe; renaming one is not.

## Colour maths

`color.nix` is standalone and has no flake or module dependency:

```nix
let color = import ./lib/color.nix { inherit lib; };
in
{
  c = color.contrast "#1e1e2e" "#cdd6f4";      # 11.341…, WCAG ratio
  m = color.mix "#000000" "#ffffff" 0.5;       # "#808080"
  l = color.lighten "#1e1e2e" 0.2;             # "#4b4b58"
  a = color.alpha "#89b4fa" 0.5;               # "#89b4fa80"
  r = color.toCssRgba "#89b4fa";               # "rgba(137, 180, 250, 1)"
  e = color.ensureContrast "#45475a" "#1e1e2e" 4.5;
  b = color.bestForeground "#1e1e2e" [ "#cdd6f4" "#ffffff" ];
}
```

Parsing accepts `#rgb`, `#rrggbb`, `#rrggbbaa`, with or without `#`, any case.
Invalid input returns `null` rather than throwing, so a bad theme value becomes
an assertion failure instead of an opaque substring error.

### Two things worth knowing

**Nix has no math builtins.** There is no `pow`, `exp`, `log` or `sqrt`, and
nixpkgs 26.11 removed `lib.pow`. The WCAG sRGB transfer curve (`x^2.4`) is
therefore computed as `x² · (x²)^(1/5)`, with the fifth root by Newton's
method. It is pinned against published WCAG values in `tests/theming_test.nix`
— `contrast(#ffffff, #808080) == 3.949` and `contrast(#ffffff, #777777) ==
4.478` — so a regression here fails a test rather than producing
plausible-looking wrong numbers.

**nixpkgs 26.11 dropped several helpers.** `lib.pow`, `lib.round`,
`lib.stringToInt`, `lib.stringToList`, `lib.elemIndex`, `lib.findFirstIndex`
and `lib.sortBy` are all gone. `color.nix` uses `genList`+`substring` for
strings and `findFirst` for lookups instead.

## Tests

```console
$ nix run .#nixtests-run          # runs tests/theming_test.nix
```

38 unit tests covering parsing, round-tripping, the WCAG reference values,
blending, legibility helpers, catalog integrity, and the two-phase override
behaviour. They are pure eval-time comparisons against `lib/` directly, so they
cannot drift from what the system uses.

Module-level assertions live in `modules/nixos/theming/tests.nix` and
`modules/home/theming/tests.nix`, and run on every host build.