---
name: rust-development
description: Rust development with crane, cargo, and Nix integration
---

## What I do

Guide Rust development within a Nix flake environment using crane for builds.

## Project Structure

```
.
├── Cargo.toml          # Rust package manifest
├── src/
│   └── main.rs         # Entry point
├── flake.nix           # Nix flake with crane
└── .envrc              # direnv integration
```

## Common Tasks

### Build the project

```bash
nix build
# Or for development
cargo build
```

### Run tests

```bash
cargo test
# Or with Nix
cargo test
```

### Add dependencies

```bash
cargo add <crate-name>
```

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Format code

```bash
cargo fmt
```

### Run clippy

```bash
cargo clippy --all-targets
```

## Key Tools Available

- `cargo` - Rust package manager
- `rustc` - Rust compiler
- `cargo-watch` - Auto-rebuild on changes
- `cargo-edit` - Dependency management
- `rust-analyzer` - LSP server

## crane Integration

This flake uses crane for:
- Incremental builds
- Caching cargo dependencies separately
- Building with Nix

To update crane inputs:
```bash
nix flake lock --update-input crane
```

## Cross-compilation

Modify `flake.nix` to add targets:
```nix
craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rustc.override {
  targets = [ "wasm32-unknown-unknown" ];
});
```
