# Testing Patterns

> Skill for writing and running tests in this NixOS configuration

## Test Hierarchy (L0–L2)

This repo uses a three-level test pyramid defined in `modules/AGENT.md`.

### L0: Nix Assertions (Mandatory)

Nix-level assertions evaluated at build time. Always required for every module.

```nix
# modules/nixos/mymodule/tests.nix
{ config, lib, ... }:
let
  cfg = config.my.services.mymodule;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port > 1024;
        message = "my.services.mymodule.port must be > 1024 (privileged ports not allowed)";
      }
    ];
  };
}
```

**Rules:**
- Always gate on `cfg.enable` — assertions must not fire when module is disabled
- One assertion per logical invariant
- Clear, actionable error messages

### L1: systemd Probes

Verify that configured services would start correctly.

```nix
# Verify the service unit parses and ExecStart is valid
systemd.services.myservice.serviceConfig.ExecStartPost =
  lib.mkIf cfg.enable "${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.port}/health";
```

### L2: Smoke Tests

Runtime validation scripts that run on the target system.

```nix
systemd.services.myservice-smoke = lib.mkIf cfg.enable {
  description = "Smoke test for myservice";
  serviceConfig.Type = "oneshot";
  script = ''
    ${pkgs.curl}/bin/curl -sf http://localhost:${toString cfg.port}/health \
      || { echo "FAIL: myservice not healthy"; exit 1; }
    echo "PASS: myservice is healthy"
  '';
};
```

## Running Tests

```bash
# L0: Check evaluation (catches assertion errors)
nix flake check --no-build

# L0+L1: Build the system
nixos-rebuild build --flake .#<hostname>

# L2: On a running system, check service status
systemctl status myservice.service
```

**Agent shortcuts:** use the `nix-eval` tool for safe L0/option checks, `nix-flake-check`
for the memory-capped flake check, and `nix-hosts` to list hosts and their profiles.

## VM Testing

Build and boot a host as a QEMU VM to validate the system closure before
deploying to real hardware:

```bash
# Build the VM runner for a host (justfile: vm-test → nix build .#<host>-vm)
just vm-test <hostname>
```

- `-vm` outputs are generated per-host by `modules/flake-parts/vm/` for hosts
  with `my.vm.enable = true` — currently only desktop (`desktop-vm`,
  `desktop-vm-headless`). Other hosts have no `.#<host>-vm` output yet.
- See [deploy-workflow.md](deploy-workflow.md) (§ Testing Deployments) for how
  VM testing fits into the deploy pipeline.

## Module Test Conventions

### Structure
Place tests in the module's `tests.nix` file. See existing examples:
- `modules/nixos/tailscale/tests.nix`
- `modules/nixos/docker/tests.nix`
- `modules/nixos/battery/tests.nix`

### Required Tests by Module Complexity

| Complexity | Required Tests |
|------------|---------------|
| Simple | L0 assertions only |
| Medium | L0 + L1 (systemd probes) |
| Complex | L0 + L1 + L2 (smoke) |

## Gotchas

### Tests must not break when module is disabled
Always gate test assertions on `cfg.enable`:
```nix
config = lib.mkIf cfg.enable {
  assertions = [ ... ];  # Won't fire when disabled
};
```

### `meta.nix` must NOT be in imports
`meta.nix` is a pure attrset, not a module. Adding it to `imports = [ ./meta.nix ]`
causes "option does not exist" errors. It is only for agents/tooling.



## Writing Good Assertions

```nix
# Good: Clear, specific, actionable
{
  assertion = cfg.port >= 1024;
  message = "my.services.myservice.port (${toString cfg.port}) must be >= 1024. "
    + "Ports below 1024 require root privileges.";
}

# Bad: Vague, doesn't explain what to fix
{
  assertion = true;  # Always passes — useless
  message = "Something is wrong";
}
```

## CI Integration

GitHub Actions workflows in `.github/workflows/`:
- `ci.yml` — Full CI (cron): `nix build .#laptop|server|wsl` + devShell builds; its `flake-check` job is commented out (fails on secret path resolution in CI)
- `build-cache.yml` — Daily binary cache warm-up builds for laptop/server/wsl
- `format-check.yml` — nixpkgs-fmt formatting
- `pr-checks.yml` — PR validation workflow
- `local-verify.yml` — Eval-only checks (`eval-check`, `format-check`, `lint-nix`, `flake-check`) for local verification
Local CI simulation with `just act*` commands (runs `local-verify.yml`):
```bash
just act            # Run all local-verify jobs
just act-eval       # Eval check only
just act-format     # Format check only
just act-lint       # Lint check only
just act-flake      # Flake check only
```
