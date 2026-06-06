# Change Heatmap

## Hot (changes every feature)

| File | Rationale |
|------|-----------|
| `src/uv2nix_template/cli/commands/` | New command class + Typer sub-app |
| `src/uv2nix_template/services/` | New service inheriting BaseService |
| `nix/module.nix` | Every new NixOS module option |
| `.github/workflows/ci.yml` | Path filters |

## Warm (changes per major version)

| File | Rationale |
|------|-----------|
| `src/uv2nix_template/models/config.py` | New config fields on AppConfig |
| `pyproject.toml` | New deps, version bump |
| `flake.nix` | New inputs |

## Cold (rarely changes)

| File | Rationale |
|------|-----------|
| `src/uv2nix_template/exceptions.py` | Exception hierarchy is stable |
| `src/uv2nix_template/cli/commands/base.py` | BaseCommand contract is stable |
| `src/uv2nix_template/services/base.py` | BaseService contract is stable |
| `nix/default.nix` | Package builder is stable |
| `nix/devshell.nix` | Dev env is stable |
| `tests/conftest.py` | Fixture contracts are stable |

## Currently unused (shells)

| File | Rationale |
|------|-----------|
| `src/textual_ui/` | Legacy alias — remove after migration to uv2nix_template.textual_ui |
| `nix/overlay.nix` | Overlay is inlined in flake.nix |
| `nix/checks.nix` | Checks are inlined in flake.nix |
| `nix/devshell.nix` | DevShells are inlined in flake.nix |
