# modules/AGENT.md — Module Structure, Schema & Type Directives

> **Scope:** Everything under `modules/<category>/`  
> **Authority:** Overrides `AGENTS.md` (repo root) where specific.  
> **Goal:** Every module is a self-contained, testable, machine-describable unit.

---

## Table of Contents

1. [Module Layout](#1-module-layout)
2. [File Responsibilities](#2-file-responsibilities)
3. [Per-Category Directives](#3-per-category-directives)
   - [3.1 NixOS Modules (`modules/nixos/`)](#31-nixos-modules-modulesnixos)
   - [3.2 nix-darwin Modules (`modules/darwin/`)](#32-nix-darwin-modules-modulesdarwin)
   - [3.3 Home Manager Modules (`modules/home/`)](#33-home-manager-modules-moduleshome)
   - [3.4 flake-parts Modules (`modules/flake-parts/`)](#34-flake-parts-modules-modulesflake-parts)
4. [`meta.nix` — Machine-Readable Contract](#4-metanix--machine-readable-contract)
5. [`tests.nix` — Required Testing](#5-testsnix--required-testing)
6. [`README.md` — Human Documentation](#6-readmemd--human-documentation)
7. [`.envrc` & Development Environment](#7-envrc--development-environment)
8. [The `my.*` Namespace](#8-the-my-namespace)
9. [Import Topology](#9-import-topology)
10. [Flat-File → Directory Migration](#10-flat-file--directory-migration)
11. [Failure Modes (Hard Gates)](#11-failure-modes-hard-gates)
12. [`my.testing` Flake-Parts Integration](#12-mytesting-flake-parts-integration)
13. [Design Philosophy](#13-design-philosophy)

---

## 1. Module Layout

A module **must** be a directory when it declares more than a handful of
options or when it mixes concerns (systemd services, home-manager config,
hardware tweaks, etc.).  Flat files (`modules/nixos/foo.nix`) are tolerated
for trivial one-liners but should be migrated to directories as soon as they
grow.

### 1.1 Directory Schema

```text
modules/<category>/<name>/
├── default.nix      # Entrypoint. Imports only. No logic.
├── meta.nix         # Machine-readable contract (Section 4)
├── tests.nix        # Required tests (Section 5)
├── README.md        # Human documentation (Section 6)
├── options.nix      # Option declarations under `my.*`
├── config.nix       # Main config implementation (`config = lib.mkIf cfg.enable { … }`)
├── services.nix     # systemd / launchd units, timers, sockets
├── packages.nix     # `environment.systemPackages` or `home.packages`
├── hardware.nix     # Kernel modules, firmware, udev rules (NixOS only)
├── home.nix         # Home-manager sub-module (imported into `home-manager.users.<name>`)
├── secrets.nix      # `age.secrets` declarations
└── …                # Any other logical side-cars
```

**Agent rule:** `default.nix` is an **import manifest**.  It contains `imports`
and nothing else.  All implementation lives in side-cars.

### 1.2 Minimal Example

```nix
# modules/nixos/example/default.nix
{ lib, ... }:
{
  imports = [
    ./meta.nix
    ./options.nix
    ./config.nix
    ./services.nix
    ./tests.nix
  ];
}
```

```nix
# modules/nixos/example/meta.nix
{
  name = "example";
  description = "Minimal example module demonstrating the schema";
  category = "demo";
  tags = [ "demo" "example" ];
  provides = [ "my.services.example" ];
  complexity = "simple";
  tested = true;
}
```

---

## 2. File Responsibilities

| File | Responsibility | Hard rule |
|------|----------------|-----------|
| `default.nix` | Import manifest | **No logic.** Only `imports = [ … ]`. |
| `meta.nix` | Machine-readable metadata | Must evaluate to an attrset (Section 4). |
| `options.nix` | Declare `my.*` options | Never declare outside `my.*` (with one exception — see Section 3.4). |
| `config.nix` | Main implementation | Use `lib.mkIf cfg.enable`. Keep under 150 lines; split if larger. |
| `services.nix` | systemd / launchd units | Only service-related config. |
| `packages.nix` | Package lists | Keep `environment.systemPackages` or `home.packages` here. |
| `hardware.nix` | Kernel, firmware, udev (NixOS) | Anything that touches `boot`, `hardware`, or `services.udev`. |
| `home.nix` | Home-manager integration | Imported via `home-manager.sharedModules` or per-user `imports`. |
| `secrets.nix` | agenix secret wiring | Declare `age.secrets.<name>` and bind paths to options. |
| `tests.nix` | Tests & assertions | Must be imported by `default.nix`. (Section 5) |
| `README.md` | Human docs | Markdown, concise, includes usage example. (Section 6) |

### 2.1 Splitting Guidelines

* **> 150 lines in `config.nix`** → extract `services.nix`, `packages.nix`, or `hardware.nix`.
* **> 10 options** → extract `options.nix`.
* **Mixing system + home config** → extract `home.nix`.
* **Secrets referenced** → extract `secrets.nix`.
* **More than one systemd / launchd unit** → extract `services.nix`.

---

## 3. Per-Category Directives

Each module category targets a different evaluation context.  The following
sections describe the specific conventions, allowed subsystems, and common
pitfalls for each.

### 3.1 NixOS Modules (`modules/nixos/`)

**Evaluation context:** NixOS system closures (`nixosConfigurations.*`).

| Concern | Directive |
|---------|-----------|
| **Options** | Must live under `my.*`. Never declare top-level `services.foo` or `programs.bar`. |
| **Packages** | Global packages via `environment.systemPackages` (place in `packages.nix`). |
| **Services** | Prefer `systemd` units/timers/sockets (place in `services.nix`). Avoid custom background scripts or Cron when systemd covers the use case. |
| **Hardware** | Kernel params, firmware, udev rules in `hardware.nix`. Keep boot-related config separate from runtime services. |
| **Users** | Declare `users.users.<name>` and `users.groups.<name>` in `config.nix` or a dedicated `users.nix` if complex. |
| **Networking** | Firewall rules via `networking.firewall.*`, interfaces via `networking.interfaces.*`. |
| **Activation** | Use `system.activationScripts` for one-time setup that must happen before boot finishes. |
| **Secrets** | Reference `config.age.secrets.<name>.path` (usually imported from `modules/nixos/secrets`). Never inline plaintext secrets. |
| **Cross-module wiring** | Do NOT import `home-manager.sharedModules` inside a NixOS module. Instead, expose options that a host config wires into `home-manager.users.<name>.my.*`. |
| **Tests** | L3 NixOS VM tests (`nixosTest`) are available and **required** when the module touches boot, filesystems, networking stacks, or hardware. |

**Agent rule:** If a NixOS module needs HM integration, declare the HM
options in a separate `modules/home/<name>.nix` (or `home.nix` side-car) so
the same feature works in standalone Home Manager configurations.

---

### 3.2 nix-darwin Modules (`modules/darwin/`)

**Evaluation context:** nix-darwin system closures (`darwinConfigurations.*`).

| Concern | Directive |
|---------|-----------|
| **Options** | Must live under `my.*`. |
| **System Defaults** | macOS preferences via `system.defaults.*` (NSGlobalDomain, dock, finder, trackpad, etc.). |
| **GUI Apps** | Prefer `homebrew.casks` for macOS-native GUI applications; use `environment.systemPackages` for CLI tools. |
| **Services** | Use `launchd` agents (`launchd.agents.*`) instead of systemd. Place them in `services.nix`. |
| **Nix Daemon** | Configure the multi-user Nix daemon via `nix.*` (e.g., `nix.settings.extra-nix-path`). |
| **Security** | Touch-ID sudo via `security.pam.enableSudoTouchId`; keychain via `security.pki.*`. |
| **Packages** | `environment.systemPackages` works like NixOS, but be aware of macOS-specific `pkgs.darwin` packages. |
| **Tests** | L3 NixOS VM tests are **not** usable on darwin. Rely on L0 assertions and L2 smoke tests. |

**Agent rule:** The darwin configuration is currently dormant but wired.
Keep modules aligned with NixOS equivalents where possible so shared
patterns (e.g. `my.programs.<name>`) translate easily when the darwin host is
reactivated.

---

### 3.3 Home Manager Modules (`modules/home/`)

**Evaluation context:** User environments, both NixOS-managed and standalone
Home Manager (`homeConfigurations.*`).

| Concern | Directive |
|---------|-----------|
| **Options** | Must live under `my.*`. |
| **Packages** | User packages via `home.packages`. Do NOT touch `environment.systemPackages`. |
| **Managed Programs** | If Home Manager provides a module (e.g. `programs.firefox`, `programs.vscode`), prefer `programs.<name>.enable` over manual config files. |
| **Dotfiles** | Use `xdg.configFile.<name>.source` / `.text` or `home.file.<path>.source`. Avoid raw string concatenation when the HM module already manages the target file. |
| **User Services** | On NixOS you may declare `systemd.user.services.*` in a side-car imported by `home-manager.sharedModules`. On standalone HM these still evaluate but only activate if the host runs systemd. |
| **Shells** | Configure `programs.zsh.*`, `programs.bash.*`, or `programs.fish.*` rather than writing static `~/.zshrc` fragments. |
| **Secrets** | Per-user secrets via `my.programs.direnv.secretFiles` (see root `AGENTS.md` §3.1). |
| **Activation** | Use `home.activation.<name>` for one-shot setup that runs during `home-manager switch`. |
| **System references** | **Never** reference `config.system.*`, `services.*`, `boot.*`, or `hardware.*` — these do not exist in standalone Home Manager. |
| **Tests** | Smoke tests should validate `home.file` source paths and activation script idempotency. |

**Agent rule:** A Home Manager module must be safe for both
`home-manager.users.<name>` (inside a NixOS config) and a standalone
`configurations/home/<name>.nix`. Do not assume NixOS-level state exists.

---

### 3.4 flake-parts Modules (`modules/flake-parts/`)

**Evaluation context:** The flake itself — outputs, `perSystem`, packages, apps,
devShells, and exported modules.

| Concern | Directive |
|---------|-----------|
| **Options** | **Exempt** from the `my.*` rule when configuring the flake *itself* (e.g. `me`, `tailnet`, `ollamaModels`). However, options that control per-host behavior (e.g. `my.testing`) **must** still live under `my.*` so that NixOS/darwin/home modules can consume them. |
| **`perSystem`** | Use `perSystem = { system, pkgs, ... }:` for packages, apps, checks, devShells, and formatter. These are evaluated once per supported platform. |
| **`flake.*`** | Use `flake.nixosModules.*`, `flake.homeModules.*`, `flake.overlays.*` to export reusable modules. Do NOT instantiate NixOS system config directly here (e.g. do not set `services.foo.enable` at the flake level). |
| **Autoload** | `flake.nix` imports **all** `.nix` files in this directory automatically. Any new file becomes a live flake module. |
| **Identity Pattern** | `config.nix` (repo root) is imported by `modules/flake-parts/config.nix`. Extend the submodule there when adding new identity fields; consume via `config.me.*` / `config.tailnet.*`. |
| **`pkgs` wiring** | Use the existing `_module.args.pkgs` pattern in `perSystem` (see root `AGENTS.md` §3.4). Do not shadow `pkgs` with a custom import unless you are adding overlays. |
| **Manual Wiring** | Packages/apps are often exposed explicitly in `perSystem.packages` / `perSystem.apps` (see `packages.nix` and `terranix.nix` for examples). Autowiring does not cover these. |
| **Cross-flake inputs** | Use `inputs.<name>` sparingly; prefer forwarding via `follows` to keep closure sizes small. Declare primary inputs in `nixos-flake.nix` under `nixos-unified.primary-inputs`. |
| **Tests** | Validate via `nix flake check` and by the `my.testing` runner. No L3 VM tests here. |

**Agent rule:** A flake-parts module configures the flake, not a machine.
Keep system-level implementation in `modules/nixos/` or `modules/home/` and
only export wiring here.

---

## 4. `meta.nix` — Machine-Readable Contract

`meta.nix` is evaluated independently of the module logic.  It must be a pure
attrset (no function arguments) so that agents and autowirers can read it
cheaply.

### 4.1 Schema

```nix
{
  # Identity
  name        = "docker";          # basename of the directory
  description = "Docker OCI runtime and daemon configuration.";
  category    = "containers";      # logical grouping: networking, desktop, media, etc.
  tags        = [ "containers" "virtualization" "docker" ];

  # What this module provides (option paths it owns)
  provides    = [ "my.virtualisation.docker" ];

  # What this module expects to exist (soft dependencies for agent reasoning)
  expects     = [ "my.networking.firewall" ];

  # Complexity hint for agents
  complexity  = "simple";          # simple | medium | complex

  # Test coverage
  tested      = true;              # true if tests.nix has meaningful coverage

  # Optional: link to upstream docs
  homepage    = "https://docs.docker.com";

  # Optional: who maintains this (GitHub handle or name)
  maintainer  = "seanc";

  # Autowiring hints (consumed by future tooling, ignored by Nix today)
  autowire = {
    enable   = true;
    priority = 100;                # lower = imported earlier. Default 100.
  };
}
```

### 4.2 Agent Rules for `meta.nix`

* **Must** evaluate without importing `default.nix`.
* **Must** be kept in sync with `options.nix`.  If an option moves or is
  renamed, update `provides`.
* **Must not** contain executable logic, `import`s, or references to `pkgs` /
  `config`.

---

## 5. `tests.nix` — Required Testing

Every module directory **must** contain a `tests.nix` that is imported by
`default.nix`.  It is acceptable for `tests.nix` to be empty for trivial
modules, but the file must exist.

### 5.1 Test Levels

| Level | Type | When required |
|-------|------|---------------|
| L0 | Nix assertions | Always. At least one `assertions` entry that guards against mis-configuration. |
| L1 | systemd / launchd probes | When the module declares a service. `ExecStartPost` health-check scripts. |
| L2 | Smoke test unit | When the module runs a daemon or exposes a port. A `Type=oneshot` unit (or activation script) that can be triggered manually. |
| L3 | NixOS VM test | When the module is critical or complex. A full `nixosTest` definition in `tests.nix`. |

### 5.2 `tests.nix` Template

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.<name>;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !(cfg.enable && config.some.conflictingOption);
      message = "my.services.<name> cannot be enabled alongside some.conflictingOption";
    }
  ];

  # ── L1: systemd probes (merged into the service in services.nix) ──────────
  # systemd.services.my-service.serviceConfig.ExecStartPost = …

  # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
  systemd.services."my-service-smoke-test" = lib.mkIf cfg.enable {
    description = "Smoke test for my-service";
    # no wantedBy — triggered manually: systemctl start my-service-smoke-test
    serviceConfig.Type = "oneshot";
    script = ''
      echo "Running smoke test..."
      # …
    '';
  };

  # ── L3: NixOS VM test (only for complex modules) ──────────────────────────
  # my.tests.<name> = nixosTest { … };
}
```

### 5.3 Agent Rules for Tests

* **L0 is mandatory.**  Even a simple assertion like "port must be > 1024"
  satisfies the requirement.
* **L1 is mandatory** when a systemd / launchd service is declared.
* **L2 is strongly encouraged** for any network-facing or long-running service.
* **L3 is optional** but required for modules that touch boot, filesystems, or
  hardware.
* Tests **must not** break evaluation when the module is disabled
  (`cfg.enable == false`).

---

## 6. `README.md` — Human Documentation

Every module directory **must** contain a `README.md`.  It should be concise
(≤ 50 lines) and follow this outline:

```markdown
# <Module Name>

One-sentence description.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.foo.enable` | `false` | Enable foo |
| `my.services.foo.port` | `8080` | Listen port |

## Usage Example

```nix
my.services.foo = {
  enable = true;
  port = 9090;
};
```

## Notes

Any caveats, upstream links, or host-specific quirks.
```

---

## 7. `.envrc` & Development Environment

Modules **must not** directly create or modify the repository root `.envrc`.
That file is a global, human-managed concern.  However, modules that introduce
tools requiring environment variables should follow these conventions.

### 7.1 Document Required Variables

List any runtime environment variables a module expects in its `README.md`:

```markdown
## Development Environment

When working with this module locally you may need:

| Variable | Source | Purpose |
|----------|--------|---------|
| `MY_API_TOKEN` | `config.age.secrets.my-api.path` | API authentication |
```

### 7.2 Use the `secretFiles` Mechanism

If a module needs secrets available in a development shell, it should expose a
`secretFiles` stanza through the existing `direnv` module rather than bloating
`.envrc`:

```nix
# In the module's config.nix or home.nix
my.programs.direnv.secretFiles.my-module = {
  vars = {
    MY_API_TOKEN = config.age.secrets.my-api-token.path;
  };
  paths = {
    MY_KEY_PATH = config.age.secrets.my-key.path;
  };
};
```

This generates `~/.config/direnv/secrets/my-module.sh` which can be sourced
from `.envrc` or from per-directory `.envrc` files.

**Agent rule:** Never hard-code secret values or secret file paths into the
root `.envrc`.  Always route secret injection through `my.programs.direnv.secretFiles`.

### 7.3 Per-Directory `.envrc`

If a module manages a sub-project (e.g. `packages/complex-app/`) that needs its
own environment, a `.envrc` inside that directory is acceptable.  It should
still follow the same rules:

* Start with `use flake` (or `use flake ..` / `use flake ../../#devShell`) if
  a devShell is available.
* Source secrets from `~/.config/direnv/secrets/` rather than inlining them.
* Never commit plaintext secrets.

---

## 8. The `my.*` Namespace

All custom options **must** live under `my.*`.  The canonical structure is:

```text
my
├── system       # system-wide settings (timezone, locale, location, audio, bluetooth)
├── services     # daemons & background services (ollama, tailscale, ssh)
├── programs     # user-facing programs (firefox, vscode, steam)
├── tools        # utility scripts & one-shots
├── virtualisation  # docker, waydroid, qemu
└── <custom>     # extend as needed, but document in meta.nix
```

**Agent rule:** Never declare `services.foo` or `programs.bar` directly in a
module under `modules/nixos/`, `modules/darwin/`, or `modules/home/`.
Always nest under `options.my`.

### 8.1 Option Naming

* Use camelCase: `my.services.natShare.wanInterface`
* Booleans: `my.services.<name>.enable`
* Lists: plural name `my.services.<name>.extraVolumes`
* Attrsets: singular key name `my.services.<name>.restart.policy`

---

## 9. Import Topology

`default.nix` must use **explicit** imports.  No directory scanning.

```nix
# GOOD
imports = [
  ./meta.nix
  ./options.nix
  ./config.nix
  ./services.nix
  ./tests.nix
];

# BAD — do not use builtins.readDir
imports = lib.mapAttrsToList (n: _: ./${n}) (builtins.readDir ./.);
```

### 9.1 Cross-Module Dependencies

If module `A` depends on options from module `B`, import `B` at the
configuration level (e.g. in `modules/nixos/default.nix`) rather than inside
`A/default.nix`.  This keeps modules loosely coupled.

---

## 10. Flat-File → Directory Migration

If a module currently exists as a flat file (`modules/nixos/foo.nix`), migrate
it to a directory when any of the following become true:

1. It declares more than 5 options.
2. It contains a systemd / launchd service.
3. It mixes system-level and home-manager config.
4. It needs an assertion or test.
5. It references agenix secrets.

**Migration steps:**

1. Create `modules/nixos/foo/`.
2. Move `foo.nix` → `foo/default.nix`.
3. Extract `options`, `config`, `services`, etc. into side-cars.
4. Add `meta.nix`, `tests.nix`, `README.md`.
5. Update `default.nix` to be an import manifest only.
6. Verify `nix flake check` or `nix run` still succeeds.

---

## 11. Failure Modes (Hard Gates)

A change will be rejected if it violates any of the following.  **Legacy flat
files are grandfathered until migrated** — new modules and refactors must comply.

| Violation | Consequence |
|-----------|-------------|
| `default.nix` contains logic instead of just `imports` | Reject — split into side-cars. |
| Missing `meta.nix` | Reject — agents cannot reason about the module. |
| Missing `tests.nix` | Reject — no validation surface. |
| Missing `README.md` | Reject — humans cannot discover the module. |
| Options declared outside `my.*` (except flake-parts identity/config) | Reject — namespace violation. |
| Implicit imports (directory scanning) | Reject — must be explicit. |
| `meta.nix` drift (stale `provides` / `description`) | Reject — contract is broken. |
| Tests break evaluation when module is disabled | Reject — tests must be gated on `cfg.enable`. |
| NixOS module references `home-manager.sharedModules` directly | Reject — use host-level wiring instead. |
| Home Manager module references `config.system.*` | Reject — not safe in standalone HM. |

---

## 12. `my.testing` Flake-Parts Integration

When working with the `my.testing` flake-parts module (`modules/flake-parts/testing.nix`):

* The module is **opt-in** — enable it with `my.testing.enable = true` in a host config.
* It generates `nix run .#test <command>` for listing, running, and dry-running hosts.
* Per-host test packages (`test-<name>`) run closure-level checks without rebuilding.
* Tests must not require building the full system closure — they only need evaluation.

**Agent rule:** When adding a new service or system-level change, enable `my.testing`
in the relevant host configuration to get automatic closure validation.

---

## 13. Design Philosophy

This module system optimises for **Machine-Readable Intent** and **Human
Discoverability**.  Every module should be understandable by:

1. **The Nix evaluator** — through pure, explicit imports.
2. **An agent / LLM** — through `meta.nix` and the predictable file schema.
3. **A human** — through `README.md` and clean separation of concerns.

Prefer boring, explicit code over clever Nix abstractions.  If a module feels
too large, split it.  If an option is hard to name, it probably belongs
elsewhere.
