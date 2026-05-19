---
name: nixos-module-dev
description: Develop NixOS modules following my.* namespace conventions
---

## What I do

Guide development of NixOS modules with proper structure and conventions.

## Module Structure

```
modules/nixos/mymodule/
├── default.nix      # Import manifest (imports only)
├── meta.nix         # Machine-readable metadata
├── options.nix      # Option declarations
├── config.nix       # Implementation
├── services.nix     # systemd units (optional)
├── tests.nix        # Tests and assertions
└── README.md        # Documentation
```

## Template Files

### default.nix

```nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./meta.nix
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
```

### meta.nix

```nix
{ lib, ... }:
{
  meta = {
    maintainers = with lib.maintainers; [ ];
    # Test categories: critical, standard, minimal, experimental
    tests = [ "standard" ];
  };
}
```

### options.nix

```nix
{ config, lib, ... }:
{
  options.my.services.myservice = {
    enable = lib.mkEnableOption "My Service";
    
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.myservice;
      description = "Package to use";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };
}
```

### config.nix

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.myservice;
in
{
  config = lib.mkIf cfg.enable {
    # Implementation here
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/myservice --port ${toString cfg.port}";
      };
    };
  };
}
```

### tests.nix

```nix
{ config, lib, ... }:
{
  # L0: Nix assertions (always run)
  assertions = lib.mkIf config.my.services.myservice.enable [
    {
      assertion = config.my.services.myservice.port > 1024;
      message = "my.services.myservice.port must be > 1024 for non-root";
    }
  ];
  
  # L1-L3: systemd probes and smoke tests go in the main config
}
```

## Key Conventions

1. **All options under `my.*`** - Never use top-level option paths
2. **Use `lib.mkEnableOption`** - Standard enable pattern
3. **Gate with `lib.mkIf cfg.enable`** - Everything conditional on enable
4. **Import all submodules** - default.nix imports meta/options/config/tests
5. **Add assertions** - Validate configuration at eval time

## Testing

### L0: Nix Assertions

Always run during evaluation:
```nix
assertions = [
  {
    assertion = cfg.port > 1024;
    message = "Port must be unprivileged";
  }
];
```

### L1: systemd Probes

Check units and services in the closure.

### L2: Smoke Tests

Basic functionality tests.

### L3: NixOS VM Tests

For critical modules:
```nix
# In tests.nix or separate test file
{
  nixosTests.my-service = pkgs.nixosTests.my-service;
}
```

## Registering the Module

Place in `modules/nixos/` - it's automatically exported as `nixosModules.mymodule`.

## Documentation

Create `README.md` with:
- Purpose description
- Usage example
- All options documented
- Troubleshooting section
