# nix-graph — Static Nix configuration graph extraction tooling

Extracts a structural graph from this nixos-config repository using
static AST parsing (tree-sitter-nix) with per-file regex fallback for
files where the grammar version's byte offsets are unreliable.

## How to run

### Extract + build graph (one-shot)

```bash
nix shell nixpkgs#python3 nixpkgs#python313Packages.tree-sitter \
  nixpkgs#python313Packages.tree-sitter-grammars.tree-sitter-nix \
  nixpkgs#python313Packages.pydantic nixpkgs#python313Packages.networkx \
  nixpkgs#python313Packages.tree-sitter-config \
  -c bash -c '
export PYTHONPATH=$(find /nix/store/*python3.13* -name site-packages -type d | tr "\n" ":"):$(find /nix/store/*tree-sitter* -name site-packages -type d | tr "\n" ":"):$PYTHONPATH
python3 tools/nix-graph/extract.py --v1-scope --validate --output tools/nix-graph/extraction-result.json
python3 tools/nix-graph/build_graph.py --input tools/nix-graph/extraction-result.json --output tools/nix-graph/graph.json
'
```

### Run MCP server

```bash
nix shell nixpkgs#python3 nixpkgs#python313Packages.networkx \
  -c bash -c '
export PYTHONPATH=$(find /nix/store/*python3.13* -name site-packages -type d | tr "\n" ":"):$PYTHONPATH
python3 tools/nix-graph/mcp_server.py --graph tools/nix-graph/graph.json
'

# Optional: pass --extraction to enable richer option-assignment queries
# python3 tools/nix-graph/mcp_server.py \
#   --graph tools/nix-graph/graph.json \
#   --extraction tools/nix-graph/extraction-result.json
```

### MCP server tools

| Tool | Description |
|------|-------------|
| `graph_stats` | Summary statistics (node/edge counts by type) |
| `node_info(node_id)` | Attributes for a single node; accepts partial paths |
| `search_nodes(query)` | Search node ids by substring |
| `get_dependents(module_path)` | Files that import the given module |
| `get_option_definers(option_path)` | Files that declare an option (DEFINES edges) |
| `find_mkforce_sites` | All `lib.mkForce` usage sites in the graph |
| `find_path(source, target)` | Shortest undirected path between two nodes |
| `find_namespace_violations` | Options set outside the `my.*` namespace |

Node IDs use prefixes: `option:*`, `module:*`, `mk:*`, `host:*`, `external:*`, `violation:*`.
Partial paths are resolved via suffix matching (e.g. `"tailscale"` matches
`"modules/nixos/tailscale"` and `"option:options.my.services.tailscale"`).

## Architecture

```
tools/nix-graph/
  extract.py       — Tree-sitter + regex hybrid extraction (Tier 1)
  build_graph.py   — NetworkX graph construction (Tier 2)
  mcp_server.py    — MCP query server (Tier 3)
  graph.json       — Generated graph data
  README.md        — This file
```

## Extraction strategy

83/120 files in v1 scope are parsed with tree-sitter via the `.text` node
property. 37 files fall back to regex when `detect_byte_offset_bug()`
detects the grammar version's byte offset issue (documented in
`ts_debug3.py`). Both paths produce identical output validated against
grep baselines.

## V1 scope

The v1 scope covers ~120 files:
- modules/nixos/common.nix
- modules/nixos/tailscale/
- modules/nixos/docker/
- modules/nixos/profiles/ (system/ + home/)
- modules/nixos/hyprland/ (all ~20 submodules)
- modules/home/bash.nix
- modules/home/core/
- modules/home/opencode/
- configurations/nixos/{desktop,laptop,server,minimal,wsl}/
- flake.nix

## Graph schema

Nodes: File{path,category}, Module{name}, Option{dotted_path}, Host{name}
Edges: IMPORTS, BELONGS_TO, DEFINES, REFERENCES, MKFORCE_ON, ENABLED_ON

## Known limitations

- Only the v1 scope file set is processed (not the full 482-file repo)
- External flake-input modules are opaque leaf nodes
- `flake.nix`'s dynamic `modules/flake-parts/*` import is resolved at
  build time via Python `os.listdir`
- The `gotty` namespace violation (`options.services.gotty` instead of
  `my.services.gotty`) is detected but is outside the v1 scope
