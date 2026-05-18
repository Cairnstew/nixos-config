# AGENTS.md — Top-Level Direction

> This is the root policy for the NixOS / nix-darwin configuration flake.
> Subdirectories may contain their own `AGENT.md` (singular) files with local rules.
> When they conflict, the **most specific** `AGENT.md` wins.

---

## 1. Project Overview

This is a multi-system Nix configuration managed by one flake.  It targets:

* **NixOS** laptops, servers, WSL instances, and cloud VMs
* **nix-darwin** (macOS) — currently dormant but wired
* **Home Manager** standalone configurations

The two structural pillars are:

1. **`flake-parts`** — module system for the flake itself (`perSystem`, `flake.*` outputs).
2. **`nixos-unified`** — provides `flakeModules.autoWire` so that files under
   `configurations/` and `modules/` are **automatically** exported as flake outputs
   without manual registration in `flake.nix`.

---

## 2. Directory → Flake Output Map (Autowiring)

| Path | Flake output |
|------|--------------|
| `configurations/nixos/<name>.nix` or `…/<name>/default.nix` | `nixosConfigurations.<name>` |
| `configurations/darwin/<name>.nix` or `…/<name>/default.nix` | `darwinConfigurations.<name>` |
| `configurations/home/<name>.nix` | `homeConfigurations.<name>` |
| `modules/nixos/<name>.nix` | `nixosModules.<name>` |
| `modules/darwin/<name>.nix` | `darwinModules.<name>` |
| `modules/home/<name>.nix` | `homeModules.<name>` |
| `modules/flake-parts/<name>.nix` | imported into `flake-parts` top-level |
| `overlays/<name>.nix` | `overlays.<name>` |
| `packages/<name>/` or `packages/<name>.nix` | manually wired in `modules/flake-parts/packages.nix` |
| `secrets/` | agenix secrets (not a flake output) |

**Agent rule:** If you add a new file in one of the autowired directories it
*will* become a flake output automatically.  Do not duplicate imports in
`flake.nix`.

---

## 3. Global Conventions

### 3.1 `config.nix` — The Identity File

`config.nix` in the repo root contains the **single source of truth** for user
identity, tailnet hosts, and Ollama model metadata.  It is imported by
`modules/flake-parts/config.nix` which turns it into typed flake-parts options.

* `me` — username, fullname, email, SSH key, GitHub handle.
* `tailnet` — Tailscale IPs / hostnames for known machines.
* `ollamaModels` — model definitions shared across AI-tool modules.

**Agent rule:** Never hard-code user-specific strings inside modules;
reference `flake.config.me.<field>` or `config.me.<field>` instead.

### 3.2 Systems & Platforms

Supported systems (from `flake.nix`):

```nix
systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
```

`perSystem` overlays and packages must be safe for all three.

### 3.3 Overlays

All overlays live in `overlays/default.nix` (or sidecars imported from there).
They are composed **once** in `flake.nix` and passed to every `pkgs` instance:

```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  overlays = lib.attrValues self.overlays;
  config.allowUnfree = true;
};
```

**Agent rule:** If you need to override or add a package, prefer an overlay so
it is available everywhere.

---

## 4. Module Conventions

For **all** modules (NixOS, darwin, home, flake-parts) see the detailed policy
in:

> **`modules/AGENT.md`**

Key take-aways:

* All custom options MUST live under the `my.*` namespace.
* Every self-contained module under `modules/<category>/<name>/` should contain:
  `default.nix`, `meta.nix`, `tests.nix`, `README.md`.
* Side-car files must be **explicitly** imported in `default.nix`; no directory
  scanning.

---

## 5. Host / Configuration Conventions

A host configuration (e.g. `configurations/nixos/laptop/default.nix`) typically:

1. Sets `nixos-unified.sshTarget = "<user>@<hostname>"` for remote activation.
2. Imports `./configuration.nix` (hardware & boot specifics) and
   `self.nixosModules.default` (the common NixOS module bundle).
3. Enables per-host features via the `my.*` option tree.
4. Declares `home-manager.users.<name>.my.*` for user-level features.

**Agent rule:** Keep host files declarative.  Extract reusable logic into a
proper `modules/nixos/<name>.nix` (or `modules/home/<name>.nix`) rather than
bloating the host file.

---

## 6. Secrets

Secrets are managed with **agenix**.

* Secret definitions: `secrets/secrets.nix`
* Encrypted blobs: `secrets/*.age`
* Decryption keys: SSH host keys or user SSH keys (declared in `secrets.nix`).

**Agent rule:** Never commit plaintext secrets.  If you need to add a new
secret, update `secrets/secrets.nix`, place the `.age` file, and reference it in
a module via `config.age.secrets.<name>.path`.

---

## 7. Common Tasks

| Task | Command |
|------|---------|
| Activate current host | `nix run` |
| Update all flake inputs | `nix flake update` or `nix run .#update` |
| Update specific inputs | `nix flake lock --update-input nixpkgs --update-input home-manager` |
| Format the tree | `nix fmt` |
| Build all outputs (CI) | `nix --accept-flake-config run github:juspay/omnix ci build` |
| Garbage collect | `sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +2 && sudo nixos-rebuild boot` |

---

## 8. Style & Lint

* Use `nixpkgs-fmt` (enforced by `nix fmt`).
* Prefer `lib.mkDefault` in common modules so host configs can override easily.
* Use `lib.mkOption` + `lib.mkEnableOption` for all new `my.*` options.
* Keep `let … in` blocks close to where they are used; avoid giant top-level
  `let` bindings in host configs.

---

## 9. Subdirectory Policies

The following subdirectories are known to carry (or will soon carry) their own
`AGENT.md` files:

* `modules/AGENT.md` — module structure, `my.*` namespace, `meta.nix`, `tests.nix`

When working inside a subdirectory, read its local `AGENT.md` first.
