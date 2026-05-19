---
name: nix-flake-basics
description: Basic Nix flake project development
---

## What I do

Guide basic Nix flake development for projects.

## Project Structure

```
.
├── flake.nix           # Nix flake definition
├── .envrc              # direnv integration
└── .gitignore          # Git ignore file
```

## Common Tasks

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Add packages to shell

Edit `flake.nix` devShell:
```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    git
    jq
    # Add your tools here
  ];
};
```

### Build project

```bash
nix build
```

### Run application

```bash
nix run
```

## Flake Structure

```nix
{
  description = "My Project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ ];
        };
      };
    };
}
```

## Adding Your Own Package

```nix
packages.default = pkgs.stdenv.mkDerivation {
  pname = "my-package";
  version = "0.1.0";
  src = ./.;
  buildPhase = ''
    echo "Building..."
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp my-script $out/bin/
  '';
};
```

## Useful Commands

```bash
# Update flake inputs
nix flake update

# Lock specific input
nix flake lock --update-input nixpkgs

# Show flake outputs
nix flake show

# Check flake
nix flake check

# Format nix files
nix fmt
```

## Tips

1. **Lockfile**: Commit `flake.lock` for reproducibility
2. **Cache**: Binary cache speeds up builds significantly
3. **Direnv**: Use `direnv` to auto-enter dev shell
4. **Documentation**: Add README.md explaining project setup
