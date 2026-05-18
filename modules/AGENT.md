# modules/AGENT.md — Module Structure & Schema

> **Scope:** Everything under `modules/<category>/`  
> **Authority:** Overrides `AGENTS.md` (repo root) where specific.  
> **Goal:** Every module is a self-contained, testable, machine-describable unit.

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
├── meta.nix         # Machine-readable contract (Section 3)
├── tests.nix        # Required tests (Section 4)
├── README.md        # Human documentation (Section 5)
├── options.nix      # Option declarations under `my.*`
├── config.nix       # Main config implementation (`config = lib.mkIf cfg.enable { … }`)
├── services.nix     # systemd units, timers, sockets
├── packages.nix     # `environment.systemPackages` or `home.packages`
├── hardware.nix     # Kernel modules, firmware, udev rules
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
    ./README.md   # if your doc system imports it; otherwise omit
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
| `meta.nix` | Machine-readable metadata | Must evaluate to an attrset (Section 3). |
| `options.nix` | Declare `my.*` options | Never declare outside `my.*`. |
| `config.nix` | Main implementation | Use `lib.mkIf cfg.enable`. Keep under 150 lines; split if larger. |
| `services.nix` | systemd units / timers | Only systemd-related config. |
| `packages.nix` | Package lists | Keep `environment.systemPackages` or `home.packages` here. |
| `hardware.nix` | Kernel, firmware, udev | Anything that touches `boot`, `hardware`, or `services.udev`. |
| `home.nix` | Home-manager integration | Imported via `home-manager.sharedModules` or per-user `imports`. |
| `secrets.nix` | agenix secret wiring | Declare `age.secrets.<name>` and bind paths to options. |
| `tests.nix` | Tests & assertions | Must be imported by `default.nix`. (Section 4) |
| `README.md` | Human docs | Markdown, concise, includes usage example. (Section 5) |

### 2.1 Splitting Guidelines

* **> 150 lines in `config.nix`** → extract `services.nix`, `packages.nix`, or `hardware.nix`.
* **> 10 options** → extract `options.nix`.
* **Mixing system + home config** → extract `home.nix`.
* **Secrets referenced** → extract `secrets.nix`.
* **More than one systemd unit** → extract `services.nix`.

---

## 3. `meta.nix` — Machine-Readable Contract

`meta.nix` is evaluated independently of the module logic.  It must be a pure
attrset (no function arguments) so that agents and autowirers can read it
cheaply.

### 3.1 Schema

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

### 3.2 Agent Rules for `meta.nix`

* **Must** evaluate without importing `default.nix`.
* **Must** be kept in sync with `options.nix`.  If an option moves or is
  renamed, update `provides`.
* **Must not** contain executable logic, `import`s, or references to `pkgs` /
  `config`.

---

## 4. `tests.nix` — Required Testing

Every module directory **must** contain a `tests.nix` that is imported by
`default.nix`.  It is acceptable for `tests.nix` to be empty for trivial
modules, but the file must exist.

### 4.1 Test Levels

| Level | Type | When required |
|-------|------|---------------|
| L0 | Nix assertions | Always. At least one `assertions` entry that guards against mis-configuration. |
| L1 | systemd probes | When the module declares a service. `ExecStartPost` health-check scripts. |
| L2 | Smoke test unit | When the module runs a daemon or exposes a port. A `Type=oneshot` unit that can be triggered manually. |
| L3 | NixOS VM test | When the module is critical or complex. A full `nixosTest` definition in `tests.nix`. |

### 4.2 `tests.nix` Template

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

  # ── L2: Smoke-test oneshot ────────────────────────────────────────────────
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

### 4.3 Agent Rules for Tests

* **L0 is mandatory.**  Even a simple assertion like "port must be > 1024"
  satisfies the requirement.
* **L1 is mandatory** when a systemd service is declared.
* **L2 is strongly encouraged** for any network-facing or long-running service.
* **L3 is optional** but required for modules that touch boot, filesystems, or
  hardware.
* Tests **must not** break evaluation when the module is disabled
  (`cfg.enable == false`).

---

## 5. `README.md` — Human Documentation

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

## 6. `.envrc` & Development Environment

Modules **must not** directly create or modify the repository root `.envrc`.
That file is a global, human-managed concern.  However, modules that introduce
tools requiring environment variables should follow these conventions.

### 6.1 Document Required Variables

List any runtime environment variables a module expects in its `README.md`:

```markdown
## Development Environment

When working with this module locally you may need:

| Variable | Source | Purpose |
|----------|--------|---------|
| `MY_API_TOKEN` | `config.age.secrets.my-api.path` | API authentication |
```

### 6.2 Use the `secretFiles` Mechanism

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

### 6.3 Per-Directory `.envrc`

If a module manages a sub-project (e.g. `packages/complex-app/`) that needs its
own environment, a `.envrc` inside that directory is acceptable.  It should
still follow the same rules:

* Start with `use flake` (or `use flake ..` / `use flake ../../#devShell`) if
  a devShell is available.
* Source secrets from `~/.config/direnv/secrets/` rather than inlining them.
* Never commit plaintext secrets.

---

## 7. The `my.*` Namespace

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
module under `modules/`.  Always nest under `options.my`.

### 7.1 Option Naming

* Use camelCase: `my.services.natShare.wanInterface`
* Booleans: `my.services.<name>.enable`
* Lists: plural name `my.services.<name>.extraVolumes`
* Attrsets: singular key name `my.services.<name>.restart.policy`

---

## 8. Import Topology

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

### 8.1 Cross-Module Dependencies

If module `A` depends on options from module `B`, import `B` at the
configuration level (e.g. in `modules/nixos/default.nix`) rather than inside
`A/default.nix`.  This keeps modules loosely coupled.

---

## 9. Flat-File → Directory Migration

If a module currently exists as a flat file (`modules/nixos/foo.nix`), migrate
it to a directory when any of the following become true:

1. It declares more than 5 options.
2. It contains a systemd service.
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

## 10. Failure Modes (Hard Gates)

A change will be rejected if it violates any of the following:

| Violation | Consequence |
|-----------|-------------|
| `default.nix` contains logic instead of just `imports` | Reject — split into side-cars. |
| Missing `meta.nix` | Reject — agents cannot reason about the module. |
| Missing `tests.nix` | Reject — no validation surface. |
| Missing `README.md` | Reject — humans cannot discover the module. |
| Options declared outside `my.*` | Reject — namespace violation. |
| Implicit imports (directory scanning) | Reject — must be explicit. |
| `meta.nix` drift (stale `provides` / `description`) | Reject — contract is broken. |
| Tests break evaluation when module is disabled | Reject — tests must be gated on `cfg.enable`. |

---

## 11. Design Philosophy

This module system optimises for **Machine-Readable Intent** and **Human
Discoverability**.  Every module should be understandable by:

1. **The Nix evaluator** — through pure, explicit imports.
2. **An agent / LLM** — through `meta.nix` and the predictable file schema.
3. **A human** — through `README.md` and clean separation of concerns.

Prefer boring, explicit code over clever Nix abstractions.  If a module feels
too large, split it.  If an option is hard to name, it probably belongs
elsewhere.
