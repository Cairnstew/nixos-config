---
name: flake-parts-dev
description: Develop flake-parts modules for Nix flake outputs
---

## What I do

Guide development of flake-parts modules for defining flake outputs.

## Module Structure

```
modules/flake-parts/
├── my-module.nix    # Module implementation
└── README.md        # Documentation (optional)
```

## Basic Template

```nix
{ config, lib, ... }:
{
  # Top-level flake outputs (platform independent)
  flake = {
    # Exported modules
    nixosModules.my-module = import ../nixos/my-module;
    
    # Templates
    templates.my-template = {
      path = ./../../templates/my-template;
      description = "Description";
    };
    
    # Overlays
    overlays.my-overlay = final: prev: { };
  };
  
  # Per-system outputs
  perSystem = { config, self', inputs', pkgs, system, ... }: {
    # Packages
    packages.my-package = pkgs.callPackage ./my-package.nix { };
    
    # Apps
    apps.my-app = {
      type = "app";
      program = "${self'.packages.my-package}/bin/my-app";
    };
    
    # Development shells
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [ ];
    };
    
    # Checks
    checks.my-check = pkgs.runCommand "my-check" { } ''
      echo "Running check..."
      touch $out
    '';
    
    # Formatter
    formatter = pkgs.nixpkgs-fmt;
  };
}
```

## Key Concepts

### `flake` vs `perSystem`

| Use | Output |
|-----|--------|
| `flake` | Platform-independent (modules, overlays, templates) |
| `perSystem` | Platform-specific (packages, apps, devShells, checks) |

### Accessing Inputs

```nix
{ inputs, ... }:
{
  perSystem = { system, ... }: {
    packages.foo = inputs.some-input.packages.${system}.foo;
  };
}
```

### Custom Options

```nix
{ config, lib, ... }:
{
  options.my.option = lib.mkOption {
    type = lib.types.str;
    default = "default";
    description = "Description";
  };
  
  config = {
    # Use config.my.option
  };
}
```

### Extending pkgs

```nix
{ config, lib, ... }:
{
  perSystem = { pkgs, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit (pkgs) system;
      overlays = lib.attrValues config.flake.overlays;
    };
  };
}
```

## Auto-wiring

In this repo, flake-parts modules are auto-wired from `modules/flake-parts/*.nix`.

Just create a `.nix` file and it becomes part of the flake.

## Common Patterns

### Package from NixOS Config

```nix
{ config, lib, ... }:
{
  perSystem = { system, ... }: {
    packages.myhost = 
      config.flake.nixosConfigurations.myhost
        .config.system.build.toplevel;
  };
}
```

### Filter by System

```nix
{ config, lib, ... }:
{
  perSystem = { system, ... }: {
    packages = lib.mapAttrs' (name: cfg: {
      name = "pkg-${name}";
      value = cfg;
    }) (lib.filterAttrs 
      (_: cfg: cfg.config.nixpkgs.hostPlatform.system == system)
      config.flake.nixosConfigurations);
  };
}
```

### Aggregating Checks

```nix
{ config, lib, ... }:
{
  perSystem = { self', ... }: {
    checks = self'.packages // {
      # Additional checks
    };
  };
}
```

## Testing

Run checks:
```bash
nix flake check
```

Build specific output:
```bash
nix build .#packages.x86_64-linux.my-package
```

## Debugging

View all outputs:
```bash
nix flake show
```

Eval specific attribute:
```bash
nix eval .#flake.nixosModules --json
```
