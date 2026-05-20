# GOTCHAS.md — Known Footguns and Fixes

> Living log of problems that have caused failures or wasted cycles.  
> **Check this before debugging any evaluation or build failure.**

---

## Format

Each entry: **symptom → cause → fix**. One paragraph max. Newest at the top.

---

**New files don't appear in flake outputs**
Symptom: `nix eval` or `nix build` errors with "does not provide attribute" or similar despite the file existing.
Cause: Nix flakes only see committed or staged files. Untracked or unstaged changes are invisible to the evaluator.
Fix: `git add .` (staging is enough, no need to commit) before running any `nix` command.

---

**Home Manager module fails in standalone mode**
Symptom: `homeConfigurations` evaluation fails with "attribute 'system' missing" or "attribute 'services' missing".
Cause: Home Manager modules were written assuming NixOS-level state exists and referenced `config.system.*`, `services.*`, `boot.*`, or `hardware.*`.
Fix: Never reference NixOS-specific options in `modules/home/`. Use only `home.*`, `programs.*`, and `xdg.*` options. Test with both `home-manager switch` standalone and as part of a NixOS config.

---

**Secret reference causes evaluation failure**
Symptom: Evaluation fails with "attribute 'cache-token' missing" when the secret doesn't exist on the current host.
Cause: Directly referencing `config.age.secrets.cache-token.path` without checking existence.
Fix: Use conditional guards: `my.services.cachix-push.enable = config.age.secrets ? "cache-token";` or check with `lib.optionalAttrs (config.age.secrets ? "cache-token")`.

---

**Options don't exist errors in host configs**
Symptom: "error: attribute 'my.services.foo' missing" or "option does not exist" when using valid-looking options.
Cause: Host config doesn't import `nixosModules.common` which provides all base options and profiles.
Fix: Always include `imports = [ flake.inputs.self.nixosModules.common ];` in every NixOS host configuration.

---

**Conflicting profile assertions fail**
Symptom: Build fails with assertion error about conflicting profiles enabled.
Cause: Enabled mutually exclusive profiles like both `gpu.mesa.enable = true` and `gpu.nvidia.enable = true`.
Fix: Pick only one option from mutually exclusive sets. Check `modules/nixos/profiles/system/` for which profiles conflict.

---

**Module tests fail when module is disabled**
Symptom: `nix flake check` fails with test errors even though `cfg.enable = false`.
Cause: Tests in `tests.nix` weren't gated on `cfg.enable` and tried to access config values that don't exist when disabled.
Fix: Wrap all test assertions in `lib.mkIf cfg.enable { ... }` or use `lib.optionalAttrs (cfg.enable) { ... }` for the test set.

---

**`meta.nix` fails to evaluate**
Symptom: "attempt to call something which is not a function" or other evaluation errors when reading module metadata.
Cause: `meta.nix` contains function arguments, imports, or references to `pkgs`/`config` instead of being a pure attrset.
Fix: `meta.nix` must be a pure attribute set with no function arguments, imports, or executable logic. It should evaluate to `{ name = "..."; description = "..."; ... }` directly.

---

**Implicit directory imports cause non-deterministic evaluation**
Symptom: Module behavior changes when files are added/removed, or "infinite recursion" errors appear.
Cause: Using `builtins.readDir` or directory scanning for imports instead of explicit file lists.
Fix: Use explicit imports in `default.nix`: `imports = [ ./meta.nix ./options.nix ./config.nix ./tests.nix ];` Never use `lib.mapAttrsToList (n: _: ./${n}) (builtins.readDir ./.)`.

---

**`default.nix` contains implementation logic**
Symptom: Code review rejection or module structure violations flagged.
Cause: `default.nix` contains more than just `imports = [ ... ]` - it has config blocks, let bindings, or option declarations.
Fix: `default.nix` is strictly an import manifest. Move all implementation to `config.nix`, options to `options.nix`, services to `services.nix`, etc.

---

**Options declared outside `my.*` namespace**
Symptom: "namespace violation" errors or rejection in code review for module changes.
Cause: Declared `services.foo.enable` or `programs.bar.enable` directly instead of under `my.*`.
Fix: All custom options must live under the `my.*` namespace: `my.services.foo.enable`, `my.programs.bar.enable`. This prevents collisions with upstream NixOS modules.

---

**Duplicate flake outputs from autowired directories**
Symptom: "attribute defined multiple times" errors in flake evaluation.
Cause: Manually importing a module in `flake.nix` that already exists in an autowired directory (`modules/nixos/`, `modules/home/`, etc.).
Fix: Files in autowired directories become flake outputs automatically. Do not duplicate imports in `flake.nix`. Either rely on autowiring or move the file out of the autowired directory.

---

**NixOS module tries to import home-manager sharedModules directly**
Symptom: Evaluation fails with "infinite recursion" or home-manager options not available.
Cause: NixOS module imported `home-manager.sharedModules` inside the module instead of exposing options for host-level wiring.
Fix: Do NOT import `home-manager.sharedModules` inside a NixOS module. Instead, expose options that a host config wires into `home-manager.users.<name>.my.*`. Create separate `modules/home/<name>.nix` for HM-specific config.

---

**Profile not applying despite being enabled**
Symptom: `my.profiles.workstation.enable = true` but audio/bluetooth/desktop environment not configured.
Cause: Profile system wasn't imported or the profile implementation has an error.
Fix: Ensure `nixosModules.common` is imported (it brings in the profile system). Check that the profile exists in `modules/nixos/profiles/system/`. Enable `my.testing.enable = true` to validate the configuration evaluates correctly.

---

**Flake-parts module accidentally configures NixOS systems**
Symptom: "attribute 'services' missing" or other NixOS-specific errors in flake evaluation.
Cause: Declared NixOS system config (like `services.foo.enable`) inside a `modules/flake-parts/` file instead of in `modules/nixos/`.
Fix: Flake-parts modules configure the flake itself (outputs, packages, options). Keep system-level implementation in `modules/nixos/` or `modules/home/` and only export wiring via `flake.nixosModules.*` in flake-parts.

---

## Adding New Entries

When you discover a new problem and its solution:

1. Add it to the **top** of this file (newest first)
2. Follow the format: **symptom → cause → fix**
3. Keep it to one paragraph
4. Include the specific error message or symptom pattern

---

Last updated: 2026-05-20
