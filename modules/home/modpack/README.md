# Modpack

Minecraft modpack engineering tooling: Modrinth API lookup via an MCP server,
plus the mods/ directory layout used by the upcoming jar-introspection and
patch-ledger slices.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.modpack.enable` | `false` | Enable modpack tooling |
| `my.programs.modpack.dataDir` | `~/.local/share/modpack` | State dir (patch ledger, metadata, backups) |
| `my.programs.modpack.modsDir` | `~/.local/share/modpack/mods` | Directory of `.jar` mod files |
| `my.programs.modpack.extraPackages` | `[]` | Extra modpack packages (e.g. `pkgs.jq`) |
| `my.programs.modpack.modrinth.baseUrl` | `https://api.modrinth.com/v2` | Modrinth API v2 base URL |
| `my.programs.modpack.modrinth.userAgent` | `nixos-config-modpack-mcp/0.1.0 (contact: seanc)` | User-Agent sent to the Modrinth API |

## Usage Example

```nix
my.programs.modpack = {
  enable = true;
  # Keep the mods folder on a large drive:
  modsDir = "/mnt/media/Modding/mods";
};
```

## MCP server: `modrinth`

Enabled automatically with the module. Tools:

| Tool | Description |
|------|-------------|
| `search_projects(query, project_type, facets, index, limit, offset)` | Search Modrinth (hits include `latest_version`, `downloads`) |
| `get_project(id_or_slug)` | Project details — includes `wiki_url`, `issues_url`, `source_url`, `status`, `body` |
| `get_project_versions(id_or_slug, game_versions, loaders)` | Version list for a project |
| `get_version(version_id)` | One version; compact `dependencies` array |
| `get_version_dependencies(version_id)` | A version's compact dependency array only |

## Notes

- **Zero-dependency Python**: the MCP server is stdlib-only (`urllib.request`),
  mirroring the `modules/home/goals` pattern — no SDK, no `pip`, no uv2nix.
- **Prefer compact endpoints**: `/version/{id}` and `/version/{id}/dependencies`
  return compact `{version_id, project_id, dependency_type}` entries. Avoid
  `/project/{id}/dependencies`, which embeds every dependency's full project
  object (observed multi-MB responses that truncate) — see the researcher
  agent's notes in `modules/home/opencode/agents/researcher.md`.
- **Wiki URLs**: `get_project` returns the official `wiki_url` field; a later
  slice will add a command/skill to curate these.
- Planned slices: `modpack-state-mcp` (zipfile jar introspection —
  `fabric.mod.json` read without extracting), `patch-ledger-mcp` (JSONL),
  `mods/` backup timer (`systemd.user.timers`).
- Enabled per-host with `my.programs.modpack.enable = true;` (not wired into a
  profile yet).
