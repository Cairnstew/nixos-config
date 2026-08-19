# Packwiz-Compatible Modpacks (Modrinth)

> Modpacks with Modrinth slugs that can be directly imported via packwiz.
> These are the easiest to add to this repo's packwiz workflow.

## Direct Packwiz Import Commands

```bash
# For each pack, run from the repo root:
just packwiz <PackName> init
just packwiz <PackName> modrinth add <mod-slug>
just packwiz-checksums <PackName>
```

## Modrinth-Available Tech Modpacks

| Pack | MC Version | Loader | Modrinth Slug | Install Command |
|------|-----------|--------|---------------|-----------------|
| Create: Astral | 1.18.2 | Fabric | `create-astral` | `packwiz modrinth add create-astral` |
| Create+ | 1.21.1 | NeoForge | `create_plus` | `packwiz modrinth add create_plus` |
| Technical Electrical | 1.21.1 | NeoForge | `technical-electrical` | `packwiz modrinth add technical-electrical` |
| Techmania | 1.20.1 | Fabric | `techmaia` | `packwiz modrinth add techmaia` |
| ATTM | 1.20.1 | Forge | `attm` | `packwiz modrinth add attm` |
| Create: Industry | 1.20.1 | Forge | `create-industry` | `packwiz modrinth add create-industry` |

## CurseForge-Only (Require Manual Conversion)

These packs are only on CurseForge and cannot be directly imported via packwiz:

| Pack | MC Version | CurseForge Slug | Notes |
|------|-----------|-----------------|-------|
| ATM10 | 1.21.1 | `all-the-mods-10` | Kitchen-sink megapack, 500+ mods |
| FTB Skies 2 | 1.21.1 | FTB launcher only | 2.82M plays, skyblock tech |
| GregTech: NH | 1.7.10 | `gt-new-horizons` | Hardcore, 3500+ quests |
| GT Community Modern | 1.20.1 | `gregtech-community-pack-modern` | Lightweight GregTech intro |
| Create: Above & Beyond | 1.18.2 | `create-above-and-beyond` | Definitive Create progression |

## Importing CurseForge Packs

For CurseForge-only packs, you can:

1. **Find a Modrinth mirror** — search Modrinth for the pack name
2. **Use the CurseForge CDN URL** — derive from file ID:
   ```
   https://edge.forgecdn.net/files/<id//1000>/<id%1000>/<filename>
   ```
   Then use `packwiz url add <url>`
3. **Export from Prism Launcher** — install via CurseForge, export as Modrinth pack, then import

## Notes

- Packwiz needs a download URL (Modrinth or direct) — CurseForge metadata-only entries won't work
- The `checksums.json` step is required after adding any mods
- Match the server's `package` loader/version to the pack's `pack.toml`
