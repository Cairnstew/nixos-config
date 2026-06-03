# Custom OpenCode Tools — NixOS Config Helper

This directory documents the custom opencode tools available at `.opencode/tools/`.

Tools are TypeScript files that provide structured, model-friendly access to repository
information. They supplement opencode's built-in tools (read, write, bash, grep, etc.)
with NixOS-configuration-specific functionality.

## Tool Reference

| Tool | Description |
|------|-------------|
| `nix-eval` | Safely evaluate Nix expressions with structured error handling |
| `nix-options` | Search the `my.*` option registry from HEATMAP.md |
| `nix-hosts` | List configured NixOS/darwin/home hosts and their profiles |
| `nix-modules` | List all modules with metadata from meta.nix files |

---

## nix-eval

Safely evaluate Nix expressions or check flake outputs. Handles common evaluation errors
and returns structured results instead of raw CLI output.

**Args:**
- `attr` (string, optional) — Flake output attribute path (e.g. `nixosConfigurations.laptop`)
- `expr` (string, optional) — Raw Nix expression to evaluate
- `raw` (boolean, default `false`) — Return raw string instead of JSON
- `apply` (string, optional) — Apply a function to the result (`--apply`)

**Examples:**
- `attr = "nixosConfigurations.laptop"` → full host config
- `attr = "nixosConfigurations.laptop.config.networking.hostName"` → specific value
- `expr = "builtins.attrNames (import <nixpkgs> {}).pkgs"` → raw expression
- `raw = true, attr = "nixosConfigurations.laptop.config.networking.hostName"` → unquoted string

**Error hints:** The tool recognizes common Nix errors (syntax errors, missing attributes,
infinite recursion, assertion failures, undefined variables) and provides fix hints
based on patterns documented in GOTCHAS.md.

---

## nix-options

Search the `my.*` option registry from HEATMAP.md. Returns matching options with type,
default value, and description.

**Args:**
- `query` (string) — Search term matching option names, sections, and descriptions
- `namespace` (string, optional) — Filter by prefix (e.g. `my.profiles`, `my.services`)

**Examples:**
- `query = "tailscale"` → all tailscale-related options
- `query = "steam", namespace = "my.programs"` → steam options only
- `query = "docker", namespace = "my.virtualisation"` → docker virtualisation options
- `query = ""` → list every registered option

**Source:** Parses `HEATMAP.md` Option Registry section (lines 146-443).

---

## nix-hosts

List all configured hosts with hostname, platform, SSH target, enabled profiles,
and config file path.

**Args:**
- `host` (string, optional) — Filter to a specific hostname
- `type` (string, default `"all"`) — Filter: `nixos`, `darwin`, `home`, or `all`

**Examples:**
- `type = "nixos"` → all NixOS hosts
- `host = "laptop"` → laptop details
- `type = "home"` → standalone Home Manager configs

**Method:** Uses `nix eval` to discover hosts from flake outputs, then reads
configuration files to extract hostname, profiles, and SSH targets.

---

## nix-modules

List all modules with metadata from their `meta.nix` files. Returns name,
description, category, provided options, complexity, and test status.

**Args:**
- `category` (string, default `"all"`) — `nixos`, `home`, `darwin`, `flake-parts`, or `all`
- `query` (string, optional) — Search by name, description, tags, or provided options
- `filter` (string, optional) — Shortcut: `untested`, `tested`, or `complex`

**Examples:**
- `category = "nixos"` → all NixOS modules
- `category = "home", filter = "complex"` → complex home modules
- `query = "networking"` → modules with networking-related tags/descriptions
- `filter = "untested"` → modules missing test coverage

**Method:** Reads `meta.nix` files directly from the filesystem (just an attrset,
no Nix evaluation needed). Falls back gracefully if module dirs exist without meta.nix.

---

## Adding New Tools

1. Create a `.ts` file in `.opencode/tools/` following the pattern:
   ```ts
   import { tool } from "@opencode-ai/plugin";

   export default tool({
     description: "Brief description for the model",
     args: { /* Zod schema */ },
     async execute(args, context) {
       // Implementation using context.worktree
       return "result";
     },
   });
   ```
2. The filename becomes the tool name (minus `.ts`).
3. Rebuild/reload opencode to pick up new tools.

---

## See Also

- [OpenCode Custom Tools Documentation](https://opencode.ai/docs/custom-tools/)
- `.opencode/tools/` — tool source files
- `HEATMAP.md` — option registry and task heatmap
- `STRUCTURE.md` — repository structure reference
