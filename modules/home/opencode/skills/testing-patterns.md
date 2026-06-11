# Testing Patterns

> Skill for writing and running tests in this NixOS configuration

## Test Hierarchy (L0–L3)

This repo uses a four-level test pyramid defined in `modules/AGENT.md`.

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

### L3: NixOS VM Tests

Full integration tests using `pkgs.testers.runNixOSTest`. Used for critical modules.

```nix
# modules/nixos/mymodule/tests.nix (L3 variant)
{ pkgs, lib, ... }:
let
  vmTest = pkgs.testers.runNixOSTest {
    name = "mymodule";
    nodes.machine = { config, ... }: {
      imports = [ ./default.nix ];
      my.services.mymodule.enable = true;
    };
    testScript = ''
      machine.start()
      machine.wait_for_unit("myservice.service")
      machine.succeed("curl -f http://localhost:8080/health")
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    # ... normal config ...
  };
  # Expose VM test as a passthru
  passthru.tests = { inherit vmTest; };
}
```

## Running Tests

```bash
# L0: Check evaluation (catches assertion errors)
nix flake check --no-build

# L0+L1: Build the system
nixos-rebuild build --flake .#<hostname>

# L2: On a running system, check service status
systemctl status myservice.service

# L3: Run full VM test for a host
just test <hostname>

# List available test hosts
just test-list
```

## Module Test Conventions

### Structure
Place tests in the module's `tests.nix` file. See existing examples:
- `modules/nixos/tailscale/tests.nix`
- `modules/nixos/docker/tests.nix`
- `modules/nixos/battery/tests.nix`

### Meta-framework (`modules/flake-parts/testing.nix`)
Provides `my.testing` options:
```nix
my.testing.enable = true;         # Enable testing framework
my.testing.vmTest.enable = true;  # Enable VM test for a host
```

### Required Tests by Module Complexity

| Complexity | Required Tests |
|------------|---------------|
| Simple | L0 assertions only |
| Medium | L0 + L1 (systemd probes) |
| Complex | L0 + L1 + L2 (smoke) |
| Critical | L0 + L1 + L2 + L3 (VM) |

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

### VM tests require KVM
`runNixOSTest` requires `/dev/kvm`. CI runners without KVM should use
`nix flake check --no-build`. Local: ensure user is in `kvm` group.

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
- `ci.yml` — Main CI: `nix flake check --no-build` (eval only, no KVM)
- `build-cache.yml` — Binary cache building
- `format-check.yml` — nixpkgs-fmt formatting
- `pr-checks.yml` — PR validation workflow
- `vm-tests.yml` — VM tests (manual dispatch, KVM-capable runners only)

Local CI simulation with `just act*` commands:
```bash
just act            # Run all local-verify jobs
just act-eval       # Eval check only
just act-format     # Format check only
just act-lint       # Lint check only
just act-flake      # Flake check only
```
