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

There are two approaches, each with different tradeoffs.

### A. File-based Nix tools (recommended for global tools)

Tools live as `.ts` files in `modules/home/opencode/tools/` and are referenced by **path** in the home module — no inline Nix strings, no escaping issues.

Adding a new tool:

1. Create a `.ts` file in `modules/home/opencode/tools/`:
   ```ts
   // modules/home/opencode/tools/my-tool.ts
   import { execSync } from "node:child_process";

   export default {
     description: "Describe what the tool does for the AI model",
     args: {
       exampleArg: { type: "string", description: "What this arg is for" },
     },
     async execute(args) {
       try {
         const out = execSync("sudo some-command --json", {
           encoding: "utf-8",
           timeout: 15_000,
         });
         return JSON.stringify(JSON.parse(out), null, 2);
       } catch (e: any) {
         return `command failed:\n${e.stderr || e.message}`;
       }
     },
   };
   ```

2. Add a path reference in `modules/home/opencode/config.nix` under the `tools` attrset:
   ```nix
   tools = lib.mkDefault {
     my-tool = ./tools/my-tool.ts;
   };
   ```

3. `git add` the new `.ts` file (must be staged for the flake evaluator to see it), then `nixos-rebuild switch`.

**CRITICAL:** Do NOT `import { tool } from "@opencode-ai/plugin"` — the global tools directory has no `node_modules/` and the import crashes opencode. The `tool()` wrapper is a runtime identity function anyway (see `GOTCHAS.md`). Use a plain object export.

**`args` format (JSON Schema, NOT Zod):**
- `{ type: "string", description: "..." }` — string arg
- `{ type: "number", description: "..." }` — number arg
- `{ type: "boolean", description: "..." }` — boolean arg
- Add `optional: true` for optional args
- Add `default: value` for defaults

**Available imports (no npm needed):**
- `node:child_process` — `execSync`, `execFileSync`, `spawnSync`
- `node:fs` — `readFileSync`, `writeFileSync`, `existsSync`
- `node:path` — `join`, `resolve`, `dirname`
- `node:os` — platform info
- `node:crypto` — hashing, UUIDs

**Error handling pattern:** Always wrap `execSync` in try/catch and return the stderr as a string — uncaught exceptions in the execute function cause opaque server errors just like the unresolvable import does.

### B. Inline Nix tools (legacy, for simple one-liners)

Define the TypeScript directly as a Nix indented string:

```nix
my-tool = ''
  export default {
    description: "A simple tool",
    args: {},
    async execute() { return "hello"; },
  }
'';
```

Same restrictions as file-based (no `@opencode-ai/plugin` import, plain object export).

**Syntax rules for Nix indented strings (`'' ... ''`):**
| Nix source | Output | Purpose |
|---|---|---|
| `''${foo}` | `${foo}` | Escape `${}` for JS template literals |
| `''''` | `'` | Escape a literal single quote |

---

## Tool lifecycle (file-based)

```
Create .ts file  →  Add path ref in config.nix  →  git add .ts  →  nixos-rebuild switch
                                                                          ↓
                                                            ~/.config/opencode/tools/<name>.ts
                                                              (symlink from Nix store)
                                                                          ↓
                                                            restart opencode → tool available
```

---

## Priority chain for overrides

| Source | Merge priority | Overrides |
|---|---|---|
| Home module (`lib.mkDefault`) | 1000 (lowest) | — |
| NixOS config (direct assignment) | 100 | Home module defaults |
| `cfg.extraConfig` (host config) | 100 (last in mkMerge) | NixOS config (same priority, last wins) |
| Explicit `lib.mkForce` | 50 (highest) | Everything |

---

## See Also

- [OpenCode Custom Tools Documentation](https://opencode.ai/docs/custom-tools/)
- `.opencode/tools/` — project-level tool source files (with `node_modules/`)
- `modules/home/opencode/tools/` — Nix-managed tool `.ts` files
- `modules/home/opencode/config.nix` — tool path references and defaults
- `modules/nixos/homeManager/config.nix` — host-specific opencode wiring
- `GOTCHAS.md` — known footgun: `import { tool }` crashes global tools
- `HEATMAP.md` — option registry and task heatmap
- `STRUCTURE.md` — repository structure reference
