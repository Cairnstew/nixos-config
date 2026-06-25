---
name: nixos-ensemble-decomposition
description: "Use when splitting NixOS configuration work into independent slices for parallel team execution. Covers how to decompose by subsystem, host, module, or concern."
---

# NixOS Ensemble Decomposition

Teaches the lead agent how to decompose NixOS/nix-darwin flake work into independent, verifiable slices that can be executed in parallel by ensemble teammates.

## Natural Decomposition Boundaries

NixOS configs decompose naturally along several axes. Choose the one that fits the work.

### By Subsystem (Most Common)

The repo's module structure at `modules/nixos/` makes subsystem boundaries clear:

| Slice | Scope | Files | Independent? |
|---|---|---|---|
| Networking | Tailscale, firewall, SSH, mDNS | `modules/nixos/tailscale.nix`, related profiles | Usually yes |
| Services | Docker, Ollama, syncthing, gitreposync | `modules/nixos/docker/`, `modules/nixos/ollama/` | Often yes |
| Hardware | GPU, CPU, power, disks | `modules/nixos/hardware/`, profiles | Yes |
| Desktop | GNOME, fonts, display manager | `modules/nixos/profiles/desktop/` | Yes |
| Secrets | agenix configs and wiring | `modules/nixos/secrets/`, `secrets/` | Mostly yes |
| Users | Home Manager configs, user mgmt | `modules/nixos/homeManager/` | Tied to secrets |
| Development | Docker, devenv, git, direnv | `modules/nixos/profiles/development.nix` | Yes |
| CI/Formatters | treefmt, act, justfile | `modules/flake-parts/` | Yes |

### By Host

When work spans multiple machines, split by hostname:

```
scout (explore): Map shared module usage across laptop, desktop, server, wsl
builder-1 (build): Apply changes to laptop and desktop
builder-2 (build): Apply changes to server
reviewer (reviewer): Verify all host configs still evaluate
```

### By Layer

When modifying a single host config, split by architectural layer:

```
scout (scout): Map current state of the host config and its imports
builder-1 (build): Add/change hardware config (disks, GPU, kernel)
builder-2 (build): Add/change profiles (workstation, desktop)
qa (qa): Add NixOS VM tests or L0 assertions for the new features
reviewer (reviewer): Review final eval and cross-layer consistency
```

### By Concern (Risky Changes)

For changes that touch secrets or critical infra:

```
scout (scout): Trace all secret usage and required agenix rules
builder (build): Implement with plan_approval: true
reviewer (reviewer): Verify no secrets leaked and proper ?-guards used
```

## Common NixOS Task Templates

### "Add a new module"

1. Scout — read `modules/AGENT.md`, `STRUCTURE.md`, and an existing module (e.g. `modules/nixos/docker/`) to understand the pattern
2. Builder — create `default.nix`, `options.nix`, `config.nix`, `meta.nix`, `tests.nix`
3. Reviewer — verify file structure matches spec and all required fields present

### "Modify a profile across hosts"

1. Scout — find all host configs and their profile imports
2. Builder — modify the profile defition in `modules/nixos/profiles/`
3. QA — add test assertions for the profile
4. Reviewer — check no host lost a required service

### "Update secrets"

1. Scout — trace the secret from `secrets/secrets.nix` to its usage sites
2. Builder — rekey/replace the `.age` file and update consuming module(s)
3. Reviewer — verify `config.age.secrets ? "name"` guards, no plaintext in store

### "Refactor a module from monolithic to directory structure"

1. Scout — read the monolithic file and identify stable split points
2. Builder-1 — create `options.nix` with option declarations
3. Builder-2 — create `config.nix` with implementation split by concern
4. Builder-3 — create `meta.nix` and `tests.nix`
5. Reviewer — verify imports, no circular deps, eval still succeeds

## Verification Gates

Before calling any NixOS work complete, run:

```bash
nix flake check --no-build        # evaluation & assertion check
```

For changes to specific host:

```bash
nix run .#test run <hostname>     # quick eval sanity
```

The lead must run these on the merged result before cleanup.

## Checklist for the Lead

- [ ] Can the work be split into 2-3 independent slices?
- [ ] Does each slice have a clear file boundary?
- [ ] Can I describe each teammate's expected output?
- [ ] Are there secret or safety concerns that need `plan_approval`?
- [ ] Have I read `STRUCTURE.md` and `HEATMAP.md` for the affected area?
- [ ] Will verification (`nix flake check --no-build`) catch integration issues?
- [ ] Did I inspect each teammate's diff before merging?
