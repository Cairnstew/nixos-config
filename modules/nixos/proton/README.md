# Proton

Enhanced Proton support for Steam — GE-Proton, ProtonUp-Qt, and extra compatibility packages.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.proton.enable` | `false` | Enable enhanced Proton support |
| `my.programs.proton.ge.enable` | `false` | Add GE-Proton (`proton-ge-bin`) to Steam compat tools |
| `my.programs.proton.protonup-qt.enable` | `false` | Install ProtonUp-Qt GUI manager |
| `my.programs.proton.extraCompatPackages` | `[]` | Extra Steam compat packages |

## Usage

```nix
my.programs.proton = {
  enable = true;
  ge.enable = true;
  protonup-qt.enable = true;
};
```

Or via the gaming profile:

```nix
my.profiles.gaming.enable = true;
```

## Notes

- Requires `my.programs.steam.enable` (or directly `programs.steam.enable`).
- GE-Proton is packaged as `proton-ge-bin` (not `proton-ge-custom`) in nixpkgs.
- `protonup-qt` allows managing GE-Proton/Wine-GE versions at runtime via a GUI.
