# Foundation Save Export Mod

Exports complete game state to JSON for save management, analysis, and backup purposes.

## Installation

Copy the `foundation-save-export` folder to your Foundation mods directory:

- **Linux**: `~/Documents/Polymorph Games/Foundation/mods/`
- **Windows**: `%USERPROFILE%/Documents/Polymorph Games/Foundation/mods/`
- **macOS**: `~/Documents/Polymorph Games/Foundation/mods/`

Enable the mod in Foundation's in-game mod manager.

## Usage

1. Load any save game or start a new game.
2. Press **F12** to trigger an export.
3. The export file is written to `mods/foundation-save-export/output/export-<timestamp>.json`.

Check the mod console (Ctrl+Shift+R to reload mods, then check the mod log) for confirmation messages.

### What is exported

- **Metadata**: mod version, game version, export timestamp, object count
- **Stats**: population, treasury, day, year (when available from the game API)
- **Objects**: every game object in the level with:
  - ID (GUID)
  - Name
  - Position (x, y, z)
  - Active state
  - All attached components with their types and enabled state

### Auto-export

The component includes an `AutoExportInterval` property. Set it to a positive integer to auto-export every N days. This can be configured by editing the component properties in the mod script.

## Building from source

From the Nix flake:

```bash
nix build .#foundation-save-export-mod
```

Or manually:

```bash
cp -r mod.json mod.lua scripts/ /path/to/mods/foundation-save-export/
```

## Files

| Path | Purpose |
|------|---------|
| `mod.json` | Mod metadata (name, version, dependencies) |
| `mod.lua` | Entry point, loads scripts |
| `scripts/export.lua` | Export logic: component registration, object iteration, JSON serialization, file output |
| `meta.nix` | Nix flake metadata |
| `README.md` | This file |

## Notes

- Exports are written to the mod's `output/` subdirectory as timestamped JSON files.
- The export is a snapshot of the current game state at the moment F12 is pressed.
- Large saves may produce multi-megabyte JSON files. JSON is used for readability and ease of processing by external tools.
