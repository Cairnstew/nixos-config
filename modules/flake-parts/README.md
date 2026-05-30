# flake-parts Layer

This directory contains **flake-parts** modules that define the flake's own
structure: identity data, package outputs, dev shells, testing infrastructure,
and integration with `nixos-unified`.

## What is flake-parts here?

`flake-parts` is the module system used to compose the flake's `outputs`.
Unlike `modules/nixos/` (which configures a NixOS machine) or `modules/home/`
(which configures a user environment), files in this directory configure the
flake evaluator itself.  They are imported automatically by `flake.nix` (both
`.nix` files and subdirectories with a `default.nix`) — see `flake.nix` imports.

---

## nixos-unified: What It Is

[nixos-unified](https://nixos-unified.org) is a **flake-parts module** (not a
separate tool or framework) that provides:

1. **Autowiring** — Automatically maps files in standard directories to flake
   outputs (e.g., `configurations/nixos/laptop/` → `nixosConfigurations.laptop`).
2. **Activation** — A single `.#activate` app that replaces `nixos-rebuild switch`,
   `darwin-rebuild switch`, and `home-manager switch`, including remote activation
   over SSH.
3. **Module arguments** — Every NixOS/darwin/home-manager module receives a
   `flake` specialArg containing `{ inputs, config, ... }` from the flake-parts
   evaluator.

### Why This Repo Uses It

- **No manual registration** — Add a file in `configurations/nixos/` and it
  automatically becomes `nixosConfigurations.<name>`. No editing `flake.nix`.
- **Unified activation** — `nix run .#activate` works on NixOS, and `nix run .#activate <host>`
  does remote deployment over SSH without extra tooling.
- **Shared config** — The `flake` specialArg lets all module types (NixOS,
  darwin, home-manager) access the same identity data from
  `modules/flake-parts/config.nix`.

---

## Autowiring: Directory → Flake Output Map

The `nixos-unified.flakeModules.autoWire` module (imported via
`nixos-flake.nix`) scans these directories and wires them automatically:

| Path | Flake Output |
|------|-------------|
| `configurations/nixos/<name>.nix` or `<name>/default.nix` | `nixosConfigurations.<name>` |
| `configurations/darwin/<name>.nix` or `<name>/default.nix` | `darwinConfigurations.<name>` |
| `configurations/home/<name>.nix` | `legacyPackages.${system}.homeConfigurations.<name>` |
| `modules/nixos/<name>.nix` or `<name>/default.nix` | `nixosModules.<name>` |
| `modules/darwin/<name>.nix` or `<name>/default.nix` | `darwinModules.<name>` |
| `modules/flake/<name>.nix` | `flakeModules.<name>` |
| `modules/home/<name>.nix` or `<name>/default.nix` | `homeModules.<name>` |
| `overlays/<name>.nix` | `overlays.<name>` |
| `packages/<name>.nix` or `<name>/default.nix` | `packages.${system}.<name>` (via `pkgs.callPackage`) |

**Key rules for agents:**

- **Never add imports in `flake.nix`** for files in these directories — they
  are already auto-wired. Doing so causes "attribute defined multiple times"
  errors (see `GOTCHAS.md`).
- **`packages/` autowiring calls `pkgs.callPackage`** on each file. If a
  package requires arguments that aren't in nixpkgs (e.g., `ventoyJson`), it
  **must not** be in `packages/`. Use an underscore prefix (`_foo/`) or place
  it elsewhere.
- **Module name = file/dir name**. `modules/nixos/foo.nix` →
  `nixosModules.foo`.

---

## The `flake` SpecialArg

Every NixOS, darwin, and home-manager module automatically receives a `flake`
argument (via `specialArgs`). It contains:

| Attribute | Description |
|-----------|-------------|
| `flake.inputs` | The `inputs` of your flake; `flake.inputs.self` refers to the flake itself |
| `flake.config` | The flake-parts `perSystem` config (includes options like `config.me`) |

### Usage pattern

```nix
{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in {
  imports = [
    # Reference a flake input as a module
    inputs.agenix.nixosModules.default
  ];

  # Use flake-parts config for shared data
  users.users.${config.me.username} = { ... };
}
```

This is how host configs in `configurations/nixos/` access `flake.config.me`
(username, email, ssh key) and `flake.inputs.self.nixosModules.common` without
any manual wiring.

**Important:** The `flake` argument is only passed to modules listed in a
`nixosSystem`/`darwinSystem`/`home-manager` `modules` list or their
`imports`. It is **not** automatically available in bare `callPackage` calls.

---

## Activation

`nixos-unified` provides `.#activate` (aliased as `packages.default` in
`nixos-flake.nix`), which replaces traditional activation commands:

| Command | What it does |
|---------|-------------|
| `nix run` | Activate the local NixOS system (uses `nixos-rebuild switch --sudo`) |
| `nix run .#activate <hostname>` | Remotely activate over SSH (uses `nixos-unified.sshTarget` option) |
| `nix run .#activate $USER@` | Activate home-manager for current user |
| `nix run .#activate $USER@$HOST` | Remotely activate home-manager over SSH |

### How remote activation works

1. Copies the flake to the remote machine via `rsync` over SSH
2. Builds the configuration on the remote machine
3. Runs the activation command (`nixos-rebuild switch` / `home-manager switch`)

**No deployment tool (deploy-rs, colmena) is needed.** For simple deploys,
`nix run .#activate <hostname>` from any machine with SSH access to the
target is sufficient.

---

## Key Flake Outputs Provided by nixos-unified

| Output | Description |
|--------|-------------|
| `packages.${system}.activate` | The activation app |
| `packages.${system}.update` | Update primary flake inputs (configured in `nixos-flake.nix`) |
| `nixos-unified.lib` | Utility functions: `mkLinuxSystem`, `mkMacosSystem`, `mkHomeConfiguration` |

---

## Package Autowiring Details

Files in `packages/` are auto-wired using `pkgs.callPackage`. This means each
file should export a function compatible with `callPackage`:

```nix
# packages/foo.nix — simple package
{ lib, writeShellApplication }:
writeShellApplication {
  name = "foo";
  text = "echo hello";
}

# packages/bar/default.nix — directory package
{ lib, stdenv }:
stdenv.mkDerivation { ... }
```

The auto-wired package becomes `packages.${system}.foo` / `packages.${system}.bar`.

**Caveat:** nixos-unified's autowire scans all files/dirs under `packages/`
with no exclude mechanism (underscore prefix does *not* skip it). If a
package needs custom arguments (like `ventoyJson`), it must live *outside*
`packages/` — e.g. in a flake-parts module directory — and be referenced
via `callPackage ./relative/path` from a flake-parts `perSystem` block.

---

## Files

1. Create a new `.nix` file in this directory, or a subdirectory with a
   `default.nix`. Both are auto-imported by `flake.nix`.
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
7. **Subdirectories** with a `default.nix` are auto-imported (like nixos-unified
   autowiring). Organize related modules into a directory with a `default.nix`
   that imports sidecar files. See `modules/flake-parts/ventoy/README.md` and
   `modules/flake-parts/deploy/README.md` for examples.
8. Run `nix fmt` and ensure `nix eval .#flake` succeeds before committing.

## Conventions

| Do | Don't |
|--|-------|
| Use `perSystem` for packages/apps that vary by platform | Declare `services.foo.enable` directly inside `perSystem` |
| Use `flake.nixosModules.*` to expose modules | Mix NixOS system config into flake-parts logic |
| Use `lib.attrValues self.overlays` when augmenting `pkgs` | Shadow `pkgs` with a custom `import nixpkgs` |
| Prefer `_module.args.pkgs` in `perSystem` | Pin a second `nixpkgs` instance without a `follows` |
| Document primary inputs in `nixos-flake.nix` | Scatter upgrade commands across many files |
