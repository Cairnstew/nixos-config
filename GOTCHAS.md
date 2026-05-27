# GOTCHAS.md — Known Footguns and Fixes

> Living log of problems that have caused failures or wasted cycles.  
> **Check this before debugging any evaluation or build failure.**

---

## Format

Each entry: **symptom → cause → fix**. One paragraph max. Newest at the top.

---

**`nix run` kills GNOME/Wayland session during activation**
Symptom: Running `nix run` (which does `nixos-rebuild switch`) kills the desktop session — GNOME Shell, pipewire, wireplumber all stop, screen goes black. The VM test (`nix run .#test run laptop`) passes fine. Cause: Home-manager's default `systemd.user.startServices` setting (`"start"`) does `systemctl --user daemon-reload` and restarts all changed user services, which includes the entire GNOME session. Fix: Set `systemd.user.startServices = "sd-switch"` in `modules/nixos/homeManager/config.nix`. The `sd-switch` method is smarter — it only restarts services whose units actually changed, avoiding the session kill.

**Windows autounattend.xml password is in plaintext over HTTP**
Symptom: The Windows admin password is visible to anyone on the PXE network. Cause: `autounattend.xml` requires a plaintext `<Password><PlainText>true</PlainText></Password>`. The file is served from `/srv/pxe/machines/<MAC>/autounattend.xml` over unencrypted HTTP during PXE boot. Fix: This is inherent to the Windows unattended install protocol. Mitigations: (1) Use an isolated PXE VLAN; (2) set a temporary password and change it after install; (3) use `password` as a plain Nix option (acceptable for lab) or `passwordFile` pointing to a file readable at eval time (agenix runtime paths like `/run/agenix/windows-password` won't work — they don't exist at eval time).

**netboot module and natShare both want dnsmasq on the same interface**
Symptom: `nixos-rebuild switch` succeeds but dnsmasq fails to start, or PXE clients get wrong DHCP leases. Cause: Both `my.services.netboot` and `my.services.natShare` enable `services.dnsmasq` and set `interface` to their own LAN interface. If both target the same interface, dnsmasq starts once with whichever config wins the merge — often the wrong one. Fix: Use different ethernet interfaces for each service, or disable one. The tests.nix assertion catches this at build time when both are on the same interface.

**`ventoy-deploy` auto-detection misses already-mounted Ventoy partition or mounts to wrong path**
Symptom: `sudo ventoy-deploy` mounts the Ventoy data partition to `/mnt/ventoy` even though udisks2 already auto-mounted it at `/run/media/$USER/Ventoy`, causing conflicts or duplicate mounts. Cause: Old script always mounted partition 2 to the hardcoded `ventoy.mountPoint` without checking if it was already mounted elsewhere. Fix: Script now calls `findmnt` to detect existing mounts before attempting its own mount. It also uses `lsblk --json`-style label matching and `ventoy -l` CLI verification for more reliable device detection. See `modules/flake-parts/ventoy.nix`.

**`ventoy-deploy` auto-detect includes `lsblk` tree-drawing characters in device path**
Symptom: `sudo ventoy-deploy` prints "Auto-detected Ventoy USB: /dev/└─sdc" then fails with "Can't lookup blockdev". Cause: `lsblk` default output uses tree formatting (with `└─`/`├─` characters) which get included in the constructed device path. Fix: Replaced `lsblk` tree output with `lsblk -dno NAME,RM` (disk-level list mode) combined with per-disk label queries via `lsblk -nlo LABEL`, eliminating the tree-formatting problem entirely. Applied in `modules/flake-parts/ventoy.nix`.

---



**Dual-boot disko module enables GRUB options but not GRUB itself**
Symptom: `nix flake check` or `nix build` fails with `You must set the option 'boot.loader.grub.devices' or 'boot.loader.grub.mirroredBoots'` when `my.disko.dualBoot.enable = true`. Cause: The disko module sets `grub.useOSProber` and `grub.extraEntries` but was missing `grub.enable = true` and `grub.devices = [ "nodev" ]` (plus `grub.efiSupport` for UEFI). The common module sets `grub.enable = lib.mkDefault false` which stays in effect unless explicitly overridden. Fix: `modules/nixos/disko/config.nix` now sets `boot.loader.grub.enable = true`, `boot.loader.grub.devices = [ "nodev" ]`, `boot.loader.grub.efiSupport = true`, and `boot.loader.efi.canTouchEfiVariables = mkDefault true` when dual-boot is enabled.

---

**`meta.nix` imported in `default.nix` causes "option does not exist" errors**
Symptom: `nix flake check` or `nix run` fails with `The option 'home-manager.users.<user>.<key>' does not exist` where `<key>` is something like `category`, `name`, or `tags`. Cause: `meta.nix` is a pure attrset (not a module function: `{ ... }: { ... }`), so importing it via `imports = [ ./meta.nix ]` in `default.nix` tries to set its keys as module-level options that don't exist in the home-manager user scope. Fix: Remove `./meta.nix` from the `imports` list in `default.nix`. `meta.nix` is metadata for agents/tooling only — it must NOT be imported as a Nix module.

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

**genisoimage needs `-joliet-long` for some Windows ISOs**
Symptom: ISO repacking fails with "have the same Joliet name" and "Joliet tree sort failed". Cause: Some Windows ISOs contain two CAB files whose long Joliet names collide after being truncated to the Joliet 64-char limit. Fix: Add `-joliet-long` to the `genisoimage` invocation to allow longer Joliet file names (up to 103 chars). Fixed in `modules/nixos/windows-installer/services.nix`.

**Repacked ISO missing UEFI boot catalog (OVMF can't boot)**
Symptom: After the installer repacks the ISO with `genisoimage`, UEFI firmware (e.g. OVMF) can't boot it — it only shows the legacy BIOS El Torito entry. Cause: The `genisoimage` command only passed `-b boot/etfsboot.com` for BIOS boot, with no `-eltorito-alt-boot` for UEFI. The original source ISO also lacked the UEFI El Torito entry (only had BIOS). Fix: Added `-eltorito-alt-boot -e efi/microsoft/boot/efisys.bin -no-emul-boot` so the repacked ISO has both BIOS and UEFI boot records. Fixed in `modules/nixos/windows-installer/services.nix`.

**Migrated from `uup-builder` to pre-built GitHub release ISOs**
Symptom: ISO built via `uup-builder` (downloading UUP files + converting via `convert.sh`) was producing corrupt/broken ISOs. Cause: The uup-dump API and conversion pipeline had reliability issues. Fix: Replaced `uup-builder` flake input with `windows-iso-src` (points to `github:Cairnstew/uup-dump-build-and-get-windows-iso`). Step 1 of the installer now downloads a pre-built ISO from a GitHub release (split zip parts via aria2 + 7z extraction) instead of building one from UUP files. Removed `windowsBuild`, `windowsBuildId`, `windowsLang`, `windowsEdition` options; added `windowsReleaseTag`, `windowsImageIndex`, `isoChecksum`. Steps 2-8 (inject autounattend, DSC, repack, EFI boot) unchanged. See `modules/nixos/windows-installer/services.nix`.

**`serviceConfig.path` is silently ignored by systemd**
Symptom: Systemd services using `serviceConfig.path = [ ... ]` log `Unknown key 'path' in section [Service], ignoring` and commands from those packages aren't found at runtime (exit code 127). Cause: `path` is a NixOS-specific service option, not a systemd `[Service]` directive — it must be a **top-level** key in the service definition, not nested inside `serviceConfig`. Fix: Move `path = [ ... ]` outside `serviceConfig`, making it a sibling of `script`, `serviceConfig`, etc. Also check `services.nix` in `modules/nixos/ollama/` which has the same pattern.

---


---

## Adding New Entries

When you discover a new problem and its solution:

1. Add it to the **top** of this file (newest first)
2. Follow the format: **symptom → cause → fix**
3. Keep it to one paragraph
4. Include the specific error message or symptom pattern

---

---

**Windows installer re-runs on every boot if `.done` is missing**
Symptom: Every NixOS boot triggers the `windows-installer` service, downloading a Windows ISO and attempting a reinstall even though Windows is already installed. Cause: The service only checks for `/var/lib/windows-installer/.done` — if that file is absent, it assumes Windows isn't installed. Fix: The service now includes a pre-flight idempotency check: it probes the Windows partition for an NTFS filesystem via `ntfs-3g.probe` and checks for `bootmgfw.efi` on the ESP. If either exists, it creates `.done` and exits immediately.

**Windows Setup overwrites GRUB as default EFI boot entry**
Symptom: After a successful Windows install, the machine boots directly into Windows instead of GRUB. Cause: Windows Setup always makes itself the first EFI boot entry. Fix: The `windows-post-install` service runs once after the first NixOS boot following Windows install. It checks if GRUB is the default entry and uses `efibootmgr --bootorder` to restore GRUB to the front. It also removes the stale "Windows 11 Setup" entry.

**DSC config is injected into Windows ISO but never applied**
Symptom: The `dsc-configuration.yaml` is placed in the ISO's OEM directory (`sources\$OEM$\$$\Setup\Scripts\`) but Windows never actually runs `dsc config set` during setup. Cause: The `autounattend.xml` had no `FirstLogonCommand` to execute the DSC bootstrap, and Windows 11 doesn't ship with DSC v3. Fix: The refactored `autounattend-xml` package now generates a bootstrap PowerShell script (`apply-dsc.ps1`) that installs PowerShell 7 + DSC v3 and applies the config. The `autounattend.xml` includes a `FirstLogonCommand` (order 5) to run this script.

**`autounattend.xml` heredoc in services.nix is fragile**
Symptom: Editing the inline XML in `services.nix` breaks string interpolation, and the XML duplicates the `packages/autounattend-xml` package. Cause: The installer service contained a 100+ line XML heredoc that was hard to maintain and had no build-time validation. Fix: The service now calls `pkgs.callPackage ../../../../packages/autounattend-xml` to build the XML at evaluation time. The generated XML is copied from the Nix store path during the install script.

**VM tests (runNixOSTest) fail with QEMU/KVM error**
Symptom: `nix flake check` or `nix build .#checks.x86_64-linux.vm-test-*` fails with "Could not access KVM kernel module" or similar. Cause: `pkgs.testers.runNixOSTest` requires `/dev/kvm` to boot the QEMU guest. Most cloud CI runners (GitHub Actions shared, GitLab.com shared) lack KVM access. Fix: Use a self-hosted runner with KVM enabled, or use `nix flake check --no-build` (evaluation only) in CI — the existing workflows in this repo already do this. The `ci.yml` workflow has explicit comments about this. A separate `vm-tests.yml` workflow exists for manual dispatch on KVM-capable runners. To run locally: ensure your user is in the `kvm` group (`sudo usermod -aG kvm $USER`) and verify with `ls -l /dev/kvm`.

---

Last updated: 2026-05-24
