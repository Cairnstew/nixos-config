# flake-parts Layer

This directory contains **flake-parts** modules that define the flake's own
structure: identity data, package outputs, dev shells, testing infrastructure,
and integration with `nixos-unified`.

## What is flake-parts here?

`flake-parts` is the module system used to compose the flake's `outputs`.
Unlike `modules/nixos/` (which configures a NixOS machine) or `modules/home/`
(which configures a user environment), files in this directory configure the
flake evaluator itself.  They are imported automatically by `flake.nix` (only
`.nix` files are picked up) — see `flake.nix` lines 103–106.

## Files

| File | Purpose |
|------|---------|
| `config.nix` | Imports `../../config.nix` and exposes identity (`me`), tailnet hosts (`tailnet`), and Ollama models (`ollamaModels`) as typed flake options. |
| `nixos-flake.nix` | Wires `nixos-unified` autoWire and primary inputs. Defines the `.#update` target. |
| `packages.nix` | Manually exports per-host `packages.<hostname>` from NixOS configurations for the matching build platform. |
| `terranix.nix` | Infrastructure-as-code entrypoint. Exports `nixosModules.terraformInfra`, `perSystem` devShell for Terraform, and `.#tf` apps. |
| `testing.nix` | The `my.testing` flake option. Generates per-host `test-<name>` packages and the `.#test` CLI runner. |

## Adding a new flake-parts module

1. Create a new `.nix` file in this directory.
2. It will be automatically imported by `flake.nix` (only `.nix` files are
   picked up thanks to the `builtins.filter` in `flake.nix`).
3. Decide if your module produces:
   - **`perSystem`** outputs (packages, apps, checks, devShells, formatter)
   - **`flake`** outputs (exported modules, overlays, top-level options)
4. For flake-level options that configure the repo itself (identity, metadata),
   use top-level `options.*` (e.g., `options.me`).
5. For options that control host behavior (like `my.testing`), declare them
   under `options.my.*` so NixOS / darwin / home modules can consume them.
6. Keep system-level implementation out of this directory.  If you need to add
   a NixOS module, create it under `modules/nixos/` and only *export* it here
   via `flake.nixosModules.<name> = import ../nixos/<name>;`.
7. Run `nix fmt` and ensure `nix eval .#flake` succeeds before committing.

## Conventions

| Do | Don't |
|--|-------|
| Use `perSystem` for packages/apps that vary by platform | Declare `services.foo.enable` directly inside `perSystem` |
| Use `flake.nixosModules.*` to expose modules | Mix NixOS system config into flake-parts logic |
| Use `lib.attrValues self.overlays` when augmenting `pkgs` | Shadow `pkgs` with a custom `import nixpkgs` |
| Prefer `_module.args.pkgs` in `perSystem` | Pin a second `nixpkgs` instance without a `follows` |
| Document primary inputs in `nixos-flake.nix` | Scatter upgrade commands across many files |
