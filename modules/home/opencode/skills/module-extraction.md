---
name: module-extraction
description: "Use when auditing this NixOS config for modules that could be extracted into standalone repos as flake inputs, when extracting a module, setting up an extracted repo for ensemble development, or managing the update workflow back to the main flake."
---

# Module Extraction

Audit, extract, and maintain standalone NixOS module repos sourced as flake inputs. Follows the pattern of `agenix-manager` and `tailscale-manager`.

## When to Use

- User asks "what modules could be extracted?" or "audit for extraction candidates"
- User picks an extraction target and wants to create the standalone repo
- User wants to set up ensemble spaces for developing an extracted module
- User wants to update a pinned extracted module from its upstream

## Phase 1: Audit

### Coupling Analysis

Run these greps to measure how coupled a module is to the repo:

```bash
# Count identity references (username, email, sshKey, colorScheme)
rg 'flake\.config\.me\.' modules/nixos/<module>/ --count

# Count self-references (secrets paths, package refs)
rg 'inputs\.self' modules/nixos/<module>/ --count

# Check cross-module option wiring (proxy upstreams, dashboard sections)
rg 'my\.services\.proxy\.' modules/nixos/<module>/ --count
```

**Zero counts = ideal extraction candidate.**

### Tiering Criteria

| Tier | Criteria | Example |
|------|----------|---------|
| **1 — High** | Zero `flake.config.me`, zero `inputs.self`, no cross-module wiring | `gitRepoSync`, `bootHealth`, `ventoy` |
| **2 — Medium** | 1-3 identity refs (all as mkOption defaults), no `inputs.self` | `docker`, `ssh`, `emailAlerts` |
| **3 — Conditional** | `inputs.self` for helper paths, or cross-module deps that can be parameterized | `minecraft-server` (server part only), `proxy` |
| **4 — Do Not Extract** | Deeply coupled to `common.nix`, host-specific, or personal config | `common`, `profiles`, `hyprland`, `home/opencode` |

### Module File Scan

For each candidate, check these files exist and are self-contained:

```
modules/nixos/<name>/
├── default.nix      # Import manifest only
├── options.nix      # All under my.* namespace
├── config.nix       # Implementation
├── tests.nix        # Assertions gated on cfg.enable
├── README.md        # Human docs
└── meta.nix         # Machine-readable metadata
```

If `options.nix` has zero `flake.config.me` refs and zero `inputs.self` refs, it is a clean extraction.

### Cross-Module Dependencies Map

Before extracting, identify what the module depends on and what depends on it:

```bash
# What does this module import from the repo?
rg 'imports\s*=' modules/nixos/<name>/config.nix

# What other modules reference this module's options?
rg 'my\.services\.<name>' modules/nixos/ --include '*.nix' -l
```

Common dependency patterns that block extraction:
- **Requires** `my.services.proxy.upstreams` → parameterize as an option
- **Requires** `flake.config.me.username` → replace with `mkOption { type = types.str; }`
- **Requires** `flake.inputs.self + /path/to/helper` → vendor the helper or pass as option
- **Registers into** `my.programs.opencode` → keep that wiring in-repo, extract only the NixOS module

## Phase 2: Extract

### Standalone Repo Structure

```
nixos-<name>/
├── flake.nix           # Flake entry point
├── flake.lock          # Pinned inputs
├── README.md           # Usage docs
├── LICENSE             # MIT or your choice
├── modules/
│   └── default.nix     # The NixOS module (moved from modules/nixos/<name>/)
├── checks/
│   └── default.nix     # nix flake check tests
└── .github/
    └── workflows/
        └── ci.yml      # Eval + check on push
```

### flake.nix Template

```nix
{
  description = "Declarative <NAME> for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add any upstream deps here (e.g. nix-minecraft, agenix)
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosModules.default = import ./modules/default.nix;
    # Export named module if useful:
    # nixosModules.<name> = import ./modules/default.nix;

    checks.x86_64-linux = import ./checks { inherit nixpkgs; };
  };
}
```

### Decoupling Checklist

Before moving code to the standalone repo:

1. **Replace `flake.config.me.*`** with plain `mkOption` defaults:
   ```nix
   # Before (coupled)
   default = flake.config.me.username;
   
   # After (decoupled)
   default = mkOption {
     type = types.str;
     description = "Username for <purpose>. Set via host config.";
   };
   ```

2. **Replace `flake.inputs.self`** paths with options:
   ```nix
   # Before (coupled)
   patchJar = import "${flake.inputs.self}/modules/nixos/minecraft-server/modpacks/patch-jar.nix" { inherit pkgs; };
   
   # After (decoupled)
   patchJar = mkOption {
     type = types.nullOr types.path;
     description = "Path to patch-jar.nix helper";
   };
   ```

3. **Parameterize cross-module wiring**:
   ```nix
   # Before (coupled to proxy)
   my.services.proxy.upstreams.mc-${name} = { ... };
   
   # After (decoupled)
   my.services.proxy.upstreams = mkIf cfg.registerProxy {
     mc-${name} = { ... };
   };
   ```

4. **Keep secrets agenix-compatible**: The standalone module should reference `config.age.secrets ? "<name>"` guards, not hard-code secret paths.

5. **Move opencode tooling separately**: If the module has opencode tools/skills (like `minecraft-server` does), keep those in-repo and only extract the NixOS module.

### Git Setup

```bash
# Create the repo
gh repo create Cairnstew/nixos-<name> --private --description "Declarative <NAME> for NixOS"
git clone git@github.com:Cairnstew/nixos-<name>.git
cd nixos-<name>

# Copy the module
cp -r /path/to/nixos-config/modules/nixos/<name>/ modules/

# Create flake.nix from template above

# Initial commit
git add -A && git commit -m "initial: extract <name> from nixos-config"
git push -u origin main
```

## Phase 3: Wire Into Main Flake

### Add as Flake Input

In `nixos-config/flake.nix`:

```nix
inputs = {
  nixos-<name> = {
    url = "github:Cairnstew/nixos-<name>";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Replace In-Repo Module

In `modules/nixos/common.nix` (or wherever the module was imported):

```nix
# Before
./<name>

# After
inputs.nixos-<name>.nixosModules.default
```

Or if the module is only imported by specific hosts:

```nix
# In configurations/nixos/<host>/default.nix
imports = [
  inputs.nixos-<name>.nixosModules.default
];
```

### Remove Old Module Files

```bash
# Stage the removal
git rm -r modules/nixos/<name>/

# If there were opencode tools/skills, keep them but update paths
# (they reference the module's files — now they need the flake input)
```

### Verify

```bash
nix flake check --no-build
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run
```

## Phase 4: Ensemble Development Setup

### Register as Agent Space

In `modules/nixos/homeManager/config.nix`, add to the `ensemble.spaces` attrset:

```nix
ensemble = {
  spaces = {
    nixos-<name> = {
      path = "/home/seanc/Projects/nixos-<name>";
      agent = "build";
      description = "Standalone <NAME> NixOS module — fix bugs, add features";
      flakeInput = "nixos-<name>";  # optional: auto-notify on push
    };
  };
};
```

### Development Workflow

1. **Work in the space**: `team_spawn(name="fix", space="nixos-<name>", prompt="fix ...", worktree=false)`
2. **Teammate commits and pushes** in the standalone repo
3. **On shutdown**: Lead gets notified with commit SHA
4. **Update the pin** in nixos-config:
   ```bash
   nix flake lock --update-input nixos-<name>
   ```

### Making Changes to the Extracted Module

**Bug fixes / features** → Work in the standalone repo (via ensemble space or directly):
```bash
cd ~/Projects/nixos-<name>
# make changes, test
nix flake check --no-build
git commit && git push
# Then update the pin in nixos-config
cd ~/nixos-config
nix flake lock --update-input nixos-<name>
git add flake.lock && git commit -m "chore: update nixos-<name>"
```

**Changes that need both repos** → Use ensemble with two spaces, or work sequentially:
1. Make the standalone repo change first
2. Push and update the pin
3. Then make the nixos-config change that consumes the new version

## Phase 5: Update Workflow

### Routine Updates (from upstream or your own changes)

```bash
# Update the flake input pin
nix flake lock --update-input nixos-<name>

# Verify eval still works
nix flake check --no-build

# Commit
git add flake.lock
git commit -m "chore: update nixos-<name> to <short-sha>"
```

### Breaking Changes

When the standalone module's options change:

1. Update the standalone repo first (version bump, migration guide in README)
2. Update the pin: `nix flake lock --update-input nixos-<name>`
3. Fix any eval errors in nixos-config caused by the option changes
4. Test: `nix flake check --no-build`

### Version Pinning

The `flake.lock` is your version pin. To pin to a specific commit:
```bash
nix flake lock --update-input nixos-<name>
# Then edit flake.lock to point to the desired revision
# (or use a tag in the standalone repo's flake.nix)
```

## Quick Reference: Extraction Candidates

Based on the audit of this repo (2026-09-24):

| Module | Tier | Coupling | Effort | Notes |
|--------|------|----------|--------|-------|
| `gitRepoSync` | 1 | Zero refs | Low | Most reusable. Pure systemd + git. |
| `bootHealth` | 1 | 1x email default | Low | Unique functionality. |
| `bootAlerting` | 1 | 1x email default | Low | Pairs with bootHealth. |
| `emailAlerts` | 2 | 3x email defaults | Low | Building block for alerting. |
| `ventoy` | 1 | Zero refs | Medium | NixOS + flake-parts combo. |
| `docker` | 2 | Decoupled already | Low | Universal. |
| `ssh` | 2 | Zero refs in module | Low | Simple, focused. |
| `mssClamp` | 1 | Zero refs | Very Low | Tiny networking fix. |
| `proxy` | 2 | Cross-module wiring | Medium | Widely useful reverse proxy. |
| `ollama` | 2 | Zero refs | Low-Med | Model management + GPU. |
| `nebula` | 2 | Examples only | Low | Mesh VPN. |
| `minecraft-server` | 3 | inputs.self for helpers | High | Split server module from opencode tools. |
| `opencode-web` | 3 | gitRepoSync + proxy deps | Medium | Needs parameterization. |

## Troubleshooting

### "evaluation fails after extraction"

Check that all `flake.config.me.*` references were replaced with options, and that `common.nix` (or the consuming host config) passes values to the new options.

### "module not found as flake output"

Ensure `flake.nix` in the standalone repo exports `nixosModules.default` (or the named variant). The main flake's `inputs.<name>.nixosModules.default` must match.

### "circular import"

The standalone module must NOT import anything from `nixos-config`. All dependencies go through options or flake inputs.

### "ensemble space won't clone"

Check that the repo exists and is accessible: `gh repo view Cairnstew/nixos-<name>`. The ensemble plugin clones into `~/.config/opencode/ensemble-spaces/<space-name>/`.
