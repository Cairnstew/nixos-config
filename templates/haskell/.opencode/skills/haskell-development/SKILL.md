---
name: haskell-development
description: Haskell development with haskell-flake and cabal
---

## What I do

Guide Haskell development within a Nix flake environment using haskell-flake.

## Project Structure

```
.
├── flake.nix           # Nix flake with haskell-flake
├── myproject.cabal     # Cabal package manifest
├── src/
│   └── Main.hs         # Entry point
└── .envrc              # direnv integration
```

## Common Tasks

### Initialize cabal project

```bash
cabal init
```

### Build the project

```nix
nix build
# Or with cabal
cabal build
```

### Run the application

```bash
cabal run
# Or with Nix
nix run
```

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Add dependencies

Edit `myproject.cabal`:
```cabal
build-depends:
    base >= 4.14 && < 5
  , text
  , aeson
```

### Run tests

```bash
cabal test
```

### Start REPL

```bash
cabal repl
```

## Key Tools Available

- `ghc` - Glasgow Haskell Compiler
- `cabal-install` - Build tool
- `haskell-language-server` - LSP server
- `hlint` - Linter (add to devShell)
- `ormolu` - Formatter (add to devShell)

## haskell-flake Configuration

Modify `flake.nix` to customize:

```nix
perSystem = { config, self', inputs', pkgs, system, ... }: {
  haskellProjects.default = {
    # Base packages
    basePackages = pkgs.haskell.packages.ghc966;
    
    # Overrides
    packages = {
      my-package.source = ./.;
    };
    
    # Settings
    settings = {
      my-package = {
        check = false;
        haddock = false;
      };
    };
    
    # Dev shell tools
    devShell.tools = hp: with hp; {
      inherit ghcid;
    };
  };
};
```

## Common Overrides

### Disable tests for a dependency

```nix
settings.my-dependency.check = false;
```

### Use a different version from Hackage

```nix
packages.my-dependency = {
  source = "1.2.3";
  override = { ... };
};
```

### Local package override

```nix
packages.my-dependency.source = ../path/to/package;
```

## Multi-package Projects

For multiple packages:

```nix
haskellProjects.default = {
  packages = {
    package-a.source = ./package-a;
    package-b.source = ./package-b;
  };
};
```

## Tips

1. **Binary cache**: Add `cache.iog.io` to substituters for faster builds
2. **GHC version**: Change `basePackages` to use different GHC
3. **Nixpkgs Haskell**: Access via `pkgs.haskellPackages`
4. **Hoogle**: Generate docs with `haskellProjects.default.devShell.hoogle = true`
