---
name: tmodloader-mod-development
description: tModLoader mod development with .NET 8 and Nix
---

## What I do

Guide tModLoader mod development within a Nix flake environment using .NET 8 SDK.

## Project Structure

```
.
├── YourMod.csproj        # SDK-style project (imports tModLoader.targets)
├── build.txt             # Build metadata (author, version, displayName)
├── description.txt       # Mod description
├── icon.png              # 80x80 mod icon
├── YourMod.cs            # Mod entry point (partial class)
├── Properties/
│   └── launchSettings.json
├── Content/
│   └── Items/            # ModItem examples
├── Common/
│   ├── Systems/          # ModSystem examples
│   └── Players/          # ModPlayer examples
├── Localization/
│   └── en-US.hjson       # English translations
├── LibIntegrations/      # Commented-out library stubs
│   ├── _SubworldLibrary.cs
│   ├── _WeaponOutLite.cs
│   └── ...
└── flake.nix             # Nix flake with dev shell
```

## Common Tasks

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Build

```bash
dotnet build
```

### Enable a library integration

1. Open `LibIntegrations/_LibraryName.cs` and uncomment the block.
2. Open `Common/Systems/LibraryIntegrationSystem.cs` and uncomment the Load() call.

## Key Tools Available

- `dotnet` (.NET 8 SDK)
- `git`

## Adding Content

- Items, NPCs, tiles: create classes in `Content/` extending `ModItem`, `ModNPC`, `ModTile`
- Systems: create in `Common/Systems/` extending `ModSystem`
- Players: create in `Common/Players/` extending `ModPlayer`
- Localization: add keys to `Localization/en-US.hjson`

## Library Dependencies

23 library stubs are provided in `LibIntegrations/`, all commented out by default.
Each guards itself with `ModLoader.HasMod()` for safe optional dependencies.
