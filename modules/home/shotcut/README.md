# Shotcut

Cross-platform non-linear video editor built on Qt6 and the MLT framework.
Edits natively against the source files (no import step), so it opens OBS
recordings directly and its multi-format timeline tolerates mixed codecs.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.shotcut.enable` | `false` | Install Shotcut |
| `my.programs.shotcut.package` | `pkgs.shotcut` | Package to install |

## Usage Example

```nix
my.programs.shotcut.enable = true;
```

## Notes

- Deliberately not `kdePackages.kdenlive`: Shotcut avoids the KDE Frameworks
  closure, which matters on the Hyprland/GTK hosts in this repo.
- Recent releases include built-in speech-to-text (Whisper-based) for
  generating subtitles, useful for clip content.
- Enabled by default in the `desktop` home profile
  (`modules/nixos/profiles/home/config.nix`).
