# GOTCHAS.md — Known Footguns and Fixes

---

**`jan.service` fails with `status=134/ABORT` — Jan AppImage bwrap sandbox conflicts with systemd hardening**

Symptom: `jan.service` fails with `code=exited, status=134` on every start after `nixos-rebuild switch`. The main `Jan serve` process exits with SIGABRT. Cause: `pkgs.jan` is an AppImage wrapped via `appimageTools.wrapType2` — the `Jan` binary is a bwrap (bubblewrap) wrapper that creates a mount namespace sandbox. The systemd service used `DynamicUser = true` (state dir at `/var/lib/private/jan`, symlinked to `/var/lib/jan`) + `NoNewPrivileges = true` + `ProtectSystem = "strict"` + `ProtectHome = true`. bwrap's `--chdir "$(pwd)"` inside the new namespace couldn't traverse `/var/lib/private/` (mode 0700, root-owned), and even if it could, `Jan serve` requires a GTK display (it's a Tauri desktop app, not headless). Fix: Converted to a home-manager user service (`systemd.user.services.jan`) that runs in the user's graphical session. The service is `PartOf = [ "graphical-session.target" ]` and has no systemd sandboxing (bwrap already sandboxes itself). The `settings.json` is deployed via `home.file` to `~/.local/share/Jan/data/settings.json`. See `modules/nixos/jan/config.nix`.

---


**`nix flake check` reliably OOMs on ventoy-deploy — use a scoped check for fast iteration**
Symptom: Running `nix flake check --show-trace` exits with code 137 (SIGKILL from OOM) while evaluating `ventoy-deploy`. The output shows all prior checks (host configs, modules, packages) passing successfully, making it ambiguous whether the overall check passed or failed. Cause: `ventoy-deploy`'s derivation pulls in a heavy Windows ISO source tree via `github:Cairnstew/uup-dump-build-and-get-windows-iso`, which OOMs the nix evaluator during the Git cache fetch. Fix: For host config iteration (the common case), use the scoped check: `nix derivation show .#checks.x86_64-linux.build-<hostname>` (e.g. `build-desktop`). This validates the NixOS system derivation directly without touching ventoy or any other unrelated output. The full `nix flake check` is only needed when explicitly validating ventoy or the full flake surface. For VM-scope validation, `nix build .#packages.x86_64-linux.desktop-vm --dry-run` is a fine substitute that also avoids the OOM trigger.
**`pkgs.jan` exports `bin/Jan` (capital J) but service used `bin/jan` — `ExecStart=203/EXEC`**

Symptom: `jan.service` fails with `status=203/EXEC` on every start. The systemd unit enters auto-restart loop. Cause: The upstream nixpkgs `pkgs.jan` package (an AppImage wrapped via `appimageTools.wrapType2`) creates `/bin/Jan` (capital J, matching `meta.mainProgram`), but `modules/nixos/jan/config.nix` had `ExecStart = "${cfg.package}/bin/jan serve ..."` (lowercase j). systemd returns `203/EXEC` (exec format error / file not found) because no file exists at that path. Fix: Use `lib.getExe cfg.package` which resolves the correct binary name from `meta.mainProgram`. See `modules/nixos/jan/config.nix:39`.

---

**`suwayomi-sync-import` timer fires independently of server — curl exit code 7**
Symptom: `suwayomi-sync-import.service` fails periodically with `status=7/NOTRUNNING`. The journal shows "restoring backup..." followed immediately by the exit, with no GraphQL response. Cause: The `suwayomi-sync-import.timer` is `wantedBy = [ "timers.target" ]` and fires on its `OnCalendar` schedule independently. The service declares `after = [ "suwayomi-server.service" ]` and `wantedBy = [ "suwayomi-server.service" ]`, but these only apply when systemd co-starts both — the timer bypasses this dependency. When the server is restarting or Tailscale IP hasn't resolved yet, the restore curl fails with `CURLE_COULDNT_CONNECT` (exit code 7) and `set -euo pipefail` propagates it. Fix: Added a retry loop (up to 10 attempts, 3s apart) around the restore curl, guarded with `|| true`, so transient connection failures are retried. See `modules/nixos/suwayomi/sync-import.nix:67-83`.

---

**`git -c safe.directory="*"` is maximally permissive — scope to the literal path instead**
Symptom: A systemd oneshot service running as root that calls `git` on a user-owned repo fails with `fatal: detected dubious ownership in repository at '/tmp/foo'`. Fix: Use `git -c safe.directory="$REPO"` where `$REPO` is the literal path to the repo (already set as a script variable from the Nix config option). Avoid `git -c safe.directory="*"` — while functionally equivalent when all git invocations are scoped to a single Nix-declared path, the wildcard would suppress the ownership check for any path passed to git in the process, including paths that come from external input (e.g. a malicious backup filename). The literal-path form is both correct and self-documenting. See `modules/nixos/suwayomi/sync.nix:44-45`.

---

**`builtins.toJSON` in zerotier config.nix double-encodes local.conf → daemon fails to parse**
Symptom: `nix run` succeeds but zerotierone fails with `ERROR: unable to parse local.conf (root element is not a JSON object)`. The service restarts in a loop. Cause: `modules/nixos/zerotier/config.nix` line 11 was calling `builtins.toJSON cfg.localConf` and passing the resulting string to upstream `services.zerotierone.localConf`. The upstream module uses `pkgs.formats.json.generate` which already serializes the value to JSON — `builtins.toJSON` double-encodes the content (JSON string wrapping JSON). When `localConf` was `null` (not set), it passed `null` instead of `{ }`, which also triggered the upstream's symlink creation for a file containing just `null`. Fix: Pass the attrset directly: `localConf = if cfg.localConf != null then cfg.localConf else { };` — let the upstream module handle serialization.

---

**`maccel-audit.service` fails with exit code 101 during `nixos-rebuild switch`**
Symptom: `nix run` (nixos-rebuild switch) succeeds but reports `maccel-audit.service` failed with `status=101/n/a`. The audit only prints `=== maccel boot audit ===` with no logger output. Subsequent boots work fine. Cause: The `maccel-logger` script uses `set -euo pipefail` and calls the `maccel` CLI (Rust binary). During a switch, the kernel module might be in a transitional state; the Rust CLI can panic (exit 101) when the sysfs interface is briefly unavailable. The `set -e` propagates the panic exit code to the service. Additionally, `EXPECTED_MODE` was set to the config value ("linear") which never matched the CLI output ("Linear Acceleration"), causing persistent WARN noise in every run. Fix: (1) Removed `set -e` from the logger script — it's a diagnostic tool and should never fail the service. (2) Changed `exit 1` to `exit 0` on missing-module checks. (3) Added `|| true` guard in the audit service script. (4) Added `modeDisplayMap` so `EXPECTED_MODE` matches the actual CLI output. See `modules/nixos/mouse/config.nix`.

---

**`tailscale-ssh-config` produces `Host null` / `Host` entries when DNSName is empty**
Symptom: `ssh server` fails with `no argument after keyword "hostname"`. The generated `/home/<user>/.ssh/config.d/tailscale` contains entries like `Host null` and `Host` with empty `HostName` lines. Cause: `tailscale status --json` can return Self/Peer entries with an empty `DNSName` string (e.g. when tailscale isn't fully authenticated). The jq filter only checked `.DNSName != null` but not `.DNSName != ""`, so empty-string DNSNames passed through and produced `HostName` with no argument. Fix: Added `.DNSName != ""` to the jq `select` filter. To recover: `sudo tee ~seanc/.ssh/config.d/tailscale > /dev/null <<< "$(head -3 ...)"` or regenerate via `sudo systemctl start tailscale-ssh-config` after deploying the fix. See `modules/nixos/tailscale/config.nix:104`.
---

**O3DE CDN fully dead — CMake overlay + nixpkgs-stable Python 3.10 workaround**
Symptom: Building `packages.x86_64-linux.o3de` tries to download 34 SDK packages from `https://d3t6xeg4fgfoum.cloudfront.net/`. Outside sandbox returns `403 AccessDenied` (CloudFront). The S3 bucket policy behind it blocks all access. CDN is fully dead. Fix: `packages/o3de/NixpkgsPackages.cmake` pre-defines `3rdParty::*` targets from nixpkgs before O3DE's package system runs, skipping the CDN. Qt targets now point at nixpkgs Qt6 (real targets instead of stubs — all 10 private headers O3DE uses are standard). Python uses `pkgs-stable.python310` from the `nixpkgs-stable` flake input (nixos-25.11). Numpy pin in requirements.txt is patched from `==1.23.0` to `>=1.24.0`. The package evaluates and passes `nix flake check`, but a full build has not been tested yet — the CMake configure was previously blocked on Python pip requirements (numpy build failure on Python 3.13); switching to Python 3.10 is expected to resolve this.

---

**Overwatch 2 "Processing Vulkan Shaders" stuck on startup**
Symptom: Overwatch 2 hangs at "Processing Vulkan Shaders" for a very long time (minutes to forever) every time it starts. Cause: The `ensure-steam-shader-cache` script in `modules/nixos/steam/config.nix` was unconditionally deleting `steamapps/shadercache/2357570` and `steamapps/compatdata/2357570` on every run, forcing Steam to re-compile all Vulkan shaders from scratch. Combined with Steam's default of using only a single CPU core for shader background processing (`ShaderBackgroundProcessingThreads` defaults to 1), compilation takes extremely long or appears stuck. Fix: Removed the destructive cache clearing from the script. Added `my.programs.steam.shaderPreCaching.backgroundThreads` option (default: `null` = auto-detect via `os.cpu_count()`). The script now writes `~/.steam/steam/steam_dev.cfg` with `unShaderBackgroundProcessingThreads <N>` and `@ShaderBackgroundProcessingThreads <N>` to use all available CPU threads. Run `ensure-steam-shader-cache` once after rebuilding, or set `backgroundThreads` explicitly (e.g. `8` for 4-core/8-thread CPU) in your host config.

---

**`windowrule = opacity a b` without class target silently ignored in Hyprland 0.55**
Symptom: Setting `windowrule = opacity 0.93 0.80` in hyprland.conf has no visible effect — windows stay fully opaque. `hyprctl clients -j` shows no `opacity` field on any window. `decoration:active_opacity` and `decoration:inactive_opacity` remain at their default of `1.0`. Cause: `windowrule = opacity` without a `class:` or `title:` target is silently ignored by Hyprland 0.55 — it doesn't apply to any windows. This was previously used as a "global" opacity hack but was never a supported syntax for setting global opacity. Fix: Use `decoration { active_opacity = 0.93; inactive_opacity = 0.80; }` instead of a windowrule. These decoration-level settings control global window opacity properly. For per-window overrides, use `windowrule = opacity a b, class:^(ClassName)$` with an explicit class target — those DO work. See `modules/nixos/hyprland/core/config.nix` and `modules/nixos/hyprland/core/options.nix`.

---

**Hyprland config parsing errors — how to read and debug**
Symptom: After rebuilding (or even `hyprctl reload`), a red notification banner appears at the top of the screen with messages like `invalid field .*: missing a value`. The generated config lives at `/nix/store/<hash>-etc-xdg-hypr-hyprland.conf`. Cause: Hyprland's `windowrule` targets use specific syntax — bare `.*` isn't valid (use `class:^(.*)$`), and `fullscreen:1` isn't a valid target prefix at all (Hyprland has no `fullscreen:` target).  
Fix:  
- Check errors live: `hyprctl configerrors` (lists all current parse errors)  
- View the debug log tail: `hyprctl rollinglog` or `hyprctl rollinglog -f` (follow mode) — this is a DRM/libinput debug ring buffer, NOT config errors  
- Config errors are stored separately and only accessible via `hyprctl configerrors`  
- Reload to re-test after fixing: `hyprctl reload`  
- Hyprland does NOT write a persistent log file by default; `rollinglog` is the in-memory ring buffer.  
- To inspect the generated config directly: `cat /etc/xdg/hypr/hyprland.conf` (the `/nix/store` path changes each rebuild but `/etc/xdg/hypr/hyprland.conf` is a symlink to the current one).  
- Valid windowrule target formats: `class:^(regex)$`, `title:^(regex)$`, `initialClass:^(regex)$`, `initialTitle:^(regex)$`, `tag:^(regex)$`. No `fullscreen:` target exists — use per-class overrides instead.  
- **`windowrule = fullscreen, class:^(...)$` triggers `invalid field fullscreen: missing a value`** in Hyprland 0.55+. `windowrule = fullscreenstate 2, class:^(...)$` also fails (`invalid field type fullscreenstate`). **Fix:** Don't use a windowrule for fullscreen. Use the application's own fullscreen facility (e.g. gamescope's `-f` flag) instead — Hyprland honors window fullscreen requests natively. These windowrule names are bind dispatchers, not windowrule types.

---

**`home-manager-<user>.service` fails on first `nix run` after changes, succeeds on second**
Symptom: `nix run` (or `nixos-rebuild switch`) fails with `Failed to restart home-manager-seanc.service` on the first run, but succeeds on the second run without any code changes.  
Cause: The service is `Type=oneshot` and its `ExecStart` runs `systemctl --user show-environment` to import session variables. On the first rebuild after changes, `switch-to-configuration` restarts `sysinit-reactivation.target` and reloads `dbus-broker`, putting the user's systemd manager in transition. The `systemctl --user` command fails because the user bus isn't available. On the second run, the session is stable so it succeeds.  
Fix: Added `Restart=on-failure` and `RestartSec=10s` to `home-manager-seanc.service` in `modules/nixos/homeManager/config.nix`. The service auto-retries after 10s, by which time the user session has settled.

---

**`qt.platformTheme.name` is not a valid option — use `qt.platformTheme` directly**
Symptom: Setting `qt.platformTheme.name = lib.mkDefault "adwaita";` in `modules/nixos/stylix/config.nix` caused `nix flake check` to fail with `A definition for option 'qt.platformTheme' is not of type 'null or one of "gnome", "gtk2", "kde", "lxqt", "qt5ct"'`. The error was masked by earlier evaluation failures that would abort before reaching this definition, so it went unnoticed.  
Cause: The NixOS `qt.platformTheme` is a simple string enum (`null | "gnome" | "gtk2" | "kde" | "lxqt" | "qt5ct"`) — not an attrset with a `name` sub-option. The `.name` suffix was cargo-culted from the upstream stylix internal theme API comment.  
Fix: Use `qt.platformTheme = lib.mkDefault "adwaita";` (no `.name`).

**`rofi-wayland` package has been merged into `rofi`**
Symptom: `programs.rofi.package = pkgs.rofi-wayland;` or including `rofi-wayland` in `environment.systemPackages` caused `error: 'rofi-wayland' has been merged into 'rofi'`.  
Cause: Upstream nixpkgs merged `rofi-wayland` into the main `rofi` package — the separate package no longer exists.  
Fix: Use `pkgs.rofi` and `programs.rofi.package = pkgs.rofi;` instead.

---

> Living log of problems that have caused failures or wasted cycles.  
> **Check this before debugging any evaluation or build failure.**

---

## Format

**`agenix-manager new` secrets disappear after `nix run .#activate`**
Symptom: A secret created via `agenix-manager new --name foo --scope main` shows up in `agenix-manager status` immediately, but disappears after the next `nix run .#activate` (or `nixos-rebuild switch`). The `.age` file still exists but the entry is gone from the manifest.  
Cause: The upstream agenix-manager module's activation script (`agenixManagerSecretsNix`) writes all 4 files to `/etc/agenix/` on every rebuild — including `secrets-manifest.json`. The CLI's `new` command saves the updated manifest to `/etc/agenix/secrets-manifest.json`, but the activation script overwrites it with the repo-tracked version (which doesn't have the new secret yet). Additionally, `common.nix` had a redundant `agenixManagerSecretsManifest` activation script that overwrote the same file again.  
Fix: `modules/nixos/common.nix` now (1) overrides `agenixManagerSecretsNix` via `lib.mkForce` to skip writing `secrets-manifest.json` (only writes `secrets.nix`, `agenix-manager-cache.json`, `keys-snapshot.json`), (2) removes the redundant `agenixManagerSecretsManifest` script, and (3) replaces it with `agenixManagerSecretsManifestBootstrap` which only creates `/etc/agenix/secrets-manifest.json` on first boot. This preserves CLI-local manifest changes across rebuilds. To force re-sync from the repo: `sudo rm /etc/agenix/secrets-manifest.json && nix run .#activate`. The Nix evaluation always reads the repo file directly (`cfg.manifestPath`), so secret decryption is unaffected.

## Format

**disk-config.nix unconditionally overrides disko module in dualBoot mode**
Symptom: Running `just deploy-with-keys desktop` rewrites the GPT, destroying Windows partitions or creating a second disko layout on another disk. Boot fails with `VFS: Can't find ext4 filesystem` on wrong device.  
Cause: `configurations/nixos/desktop/disk-config.nix` defines `disko.devices.disk.main` unconditionally with a full GPT layout (ESP, MSR, Windows 80G, NixOS). The dualBoot module at `modules/nixos/disko/config.nix` also defines it conditionally via `mkIf isFresh`. When `mode = "useExisting"`, the module's `mkIf false` evaluates to `{}`, but `disk-config.nix` fills it back in with the full layout. nixos-anywhere sees the merged disko config and runs `disko --mode create,format,mount` — rewriting the GPT.  
Fix: Gate `disk-config.nix`'s definitions behind `lib.mkIf (!config.my.disko.dualBoot.enable)`. The dualBoot module's `useExisting` mode only sets `fileSystems."/"` and `fileSystems."/boot"` — no `disko.devices`. Use `just deploy-desktop` (passes `--phases kexec,install,reboot` to skip the disko phase entirely). The NixOS partition (`sda4`) must be created manually once via `sgdisk` + `mkfs.ext4 -L nixos /dev/sda4`. The Windows ESP is referenced by filesystem label (`/dev/disk/by-label/EFI`) instead of disko's partlabel, which doesn't exist when disko is bypassed.

---

Each entry: **symptom → cause → fix**. One paragraph max. Newest at the top.

---

**OpenCode global tool with `import { tool } from "@opencode-ai/plugin"` crashes server**
Symptom: Adding `my.programs.opencode.tools.print-test = ''import { tool } from "@opencode-ai/plugin" ...''` causes opencode to fail with `Unexpected server error` on any request. Without the tool, opencode works. Cause: Global tools at `~/.config/opencode/tools/` have no `package.json`/`node_modules/` (unlike project-level `.opencode/tools/` which do), so the `@opencode-ai/plugin` import can't be resolved and opencode's tool runtime crashes. The `tool()` function is a runtime identity function (returns `input` unchanged) — it only provides TypeScript types. `tool.schema` is just `zod`. Fix: Define tools as plain object exports without the import: `export default { description: "...", args: { key: { type: "string", description: "..." } }, async execute(args) { return "..."; } }`. The `{ type: "string", ... }` format is native JSON Schema that opencode's runtime consumes directly. The `tool()` wrapper adds no runtime behavior.

---

**`sudo act` fails on Docker 29+ — two separate errors with different fixes**
Symptom 1: Running `sudo act` fails with `Error response from daemon: mkdirat var/run/act: path escapes from parent`. Cause: Docker 27+ hardened `docker cp` to reject relative paths. `act` copies the workspace into the container via `docker cp` which triggers this check. Fix: Use `act --bind` to bind-mount the workspace instead of copying.
Symptom 2: Even with `--bind`, act fails with `Error response from daemon: mkdirat var/run: file exists` when extracting workflow metadata to `/var/run/act/`. Docker 29.x's `mkdirat` check fails because `/var/run -> /run` is a symlink in the container image, and `docker cp` cannot follow it. Fix: Use a custom image where `/var/run` is a real directory (not a symlink). Run `just act-image` to build `act-fixed:latest` from `modules/flake-parts/act-fixed.Dockerfile` which replaces the symlink with a real directory. Pass `-P ubuntu-latest=act-fixed:latest` to act. The `act-verify` wrapper, `.#act` app, and all `just act*` recipes include both `--bind` and `-P ubuntu-latest=act-fixed:latest` by default.

---

**ventoy-deploy env-var contract — packages/ventoy-deploy/default.nix → ventoy-deploy.sh**
Symptom: Calling `ventoy-deploy` outside the Nix wrapper (e.g. sourcing ventoy-deploy.sh directly in a test) fails with confusing errors about missing variables, or succeeds silently but does nothing. Cause: The script reads all its configuration from environment variables set by `packages/ventoy-deploy/default.nix`. `VENTOY_JSON` is mandatory (must point to a valid `ventoy.json` file path) — without it the script hits `cp '' destin`. `BUILD_INSTALLER_ISO`, `ISO_MAPPINGS`, `FILE_MAPPINGS`, `DEFAULT_DEVICE`, `MOUNT_POINT`, `SECURE_BOOT`, `GPT`, `LABEL` are required by the Nix wrapper but can be empty/zero. `GRUB_CFG`, `INSTALLER_ISO`, `RESERVE_SIZE_MB` are optional and only accessed when their enabling flags are set. Fix: Always run `ventoy-deploy` as the built binary (`nix build .#ventoy-deploy`). For testing, export the mandatory vars manually before sourcing the script. See `packages/ventoy-deploy/default.nix` lines 1-14 for the full parameter list.

**nixos-anywhere deploy fails — `nixos-anywhere` not found or wrong flake path**
Symptom: `nix run .#deploy-<host> -- <target>` errors with `nixos-anywhere: command not found` or `error: flake 'path:...' does not provide attribute 'nixosConfigurations.server'`. Cause: `--flake ".#$host"` resolves relative to CWD — if run outside the flake root, the config won't be found. Fix: Always run deploy from the flake root. Use `just deploy-run <host>` which ensures correct CWD.

**Desktop dual-boot: nixos-anywhere skips disko but target isn't partitioned yet**
Symptom: nixos-anywhere runs `install` phase but fails because `/mnt` filesystems don't exist. Cause: Desktop uses `useExisting` mode which has no `disko.devices` — nixos-anywhere skips the disko phase entirely. The NixOS partition must exist before deployment. Fix: Before deploying to the desktop, boot a NixOS live USB, check `lsblk`, create a partition in the free space with `mkfs.ext4 /dev/nvme0n1p5`, and update `nixosPartition` in `configurations/nixos/desktop/default.nix` if the device is different. Run `nix run .#deploy-desktop -- <IP>` which uses `--phases kexec,install,reboot`.

**Post-install: agenix secrets not decrypted on first boot**
Symptom: After nixos-anywhere install, the machine boots but agenix secrets (tailscale auth key, GitHub token, etc.) aren't decrypted — services that depend on them fail. Cause: agenix encrypts secrets with the host's SSH key (`/etc/ssh/ssh_host_ed25519_key.pub`). On first boot, this key is freshly generated by OpenSSH and doesn't match any key that secrets were encrypted with. Fix (two options):
- **Preferred:** The deploy wrapper auto-detects when host key pre-provisioning is needed (host has `disk-config.nix` sidecar). Before deploying, run `nix run .#prepare-keys-<host>` to generate the key pair, add the public key to `modules/nixos/common.nix` (`agenixManager.keys.systems`), then `agenix-manager rekey`. Then `just deploy-run <host> <ip>` will include `--extra-files` automatically.
- **Existing workaround (post-deploy):** Fetch the new host key, add it to `modules/nixos/common.nix` under `agenixManager.keys.systems`, run `agenix-manager rekey` to re-encrypt all secrets, then rebuild. This is only needed once per machine.

**`nix flake check` fails after adding disk-config.nix — disko module not imported**
Symptom: `nix flake check` errors with `The option 'disko.devices' does not exist` when evaluating a host that imports `disk-config.nix`. Cause: The disko NixOS module must be imported before any `disko.devices` option can be set. The host config must have `inputs.disko.nixosModules.default` in its imports (which happens via `nixosModules.common` → `modules/nixos/disko/default.nix`). If the host doesn't import `common.nix`, disko options won't exist. Fix: Always import `flake.inputs.self.nixosModules.common` in every NixOS host config that uses `disk-config.nix`.

**DSC config always null in netboot autounattend — Windows installs come unconfigured**
Symptom: Every PXE-installed Windows machine has no registry tweaks, WSL features, or telemetry reduction applied, even though the `autounattend.xml` bootstraps DSC. Cause: The autounattend builder parameter `dscConfigPath` was always passed as `null` from the netboot module, and the `apply-dsc.ps1` bootstrap script looked for a YAML file at `C:\Windows\Setup\Scripts\dsc-configuration.yaml` that was never injected. Fix: Refactored into three parts: (1) autounattend-xml package now takes `dscConfigYaml` (string) instead of `dscConfigPath` (path), and generates `apply-dsc.ps1` with the YAML embedded as a PowerShell here-string; (2) netboot/options.nix adds a `dscConfig` attrs option on both machine and profile submodules; (3) netboot/config.nix calls `flake.inputs.dscnix.lib.evalDscConfiguration` to render the YAML from the machine's `dscConfig`, passes it to the builder, and symlinks `apply-dsc.ps1` into the HTTP root alongside `autounattend.xml`. The `FirstLogonCommand` downloads the script via `iex (iwr ...).Content` from the PXE HTTP server. See `packages/autounattend-xml/default.nix` and `modules/nixos/netboot/config.nix`.

---

**natShare and netboot both enable dnsmasq on the same interface, silently merging configs**
Symptom: The desktop PXE client gets a DHCP lease but never receives iPXE binaries — it gets stuck at "DHCP lease acquired, then nothing". Cause: natShare enables dnsmasq with a plain `dhcp-range` for internet sharing, and netboot (in daemon mode) enables its own dnsmasq with `dhcp-range` + PXE boot options on the same interface. Nix's attrset merge silently combines both configs, but dnsmasq only uses one `dhcp-range` directive, usually the wrong one, and the PXE-specific `dhcp-boot`/`dhcp-match` options may be lost entirely. Fix: When netboot detects natShare is co-located on the same interface (`sameAsNatShare`), it skips its own dnsmasq and delegates PXE options to natShare via `my.services.natShare.extraDnsmasqSettings`. The natShare module merges these extra settings into its dnsmasq `settings` attrset via `//` merge. See `modules/nixos/netboot/config.nix` lines 297-308 and `modules/nixos/natShare/config.nix` lines 45-53 for the delegation plumbing.

---

**`netboot-serve` heredocs fail build with `writeShellApplication`**
Symptom: Building `netboot-serve` fails with `syntax error near unexpected token '}'` or shellcheck SC2034 warnings after editing the script. Cause: `writeShellApplication` runs `shellcheck --severity=error` and `bash -n` on the script. Heredoc delimiters (like `IPXE`) must be at column 0 in the generated script, but Nix indented strings (`''...''`) strip the common prefix, leaving them indented. Also, unused variables cause SC2034 which is treated as error. Fix: Use `{ echo '...'; echo '...'; } > file` blocks instead of heredocs. Delete or prefix unused variables with `_`. Test locally with `nix build .#netboot-serve`.

---

**`tailscale-manager` fails on first deploy because Terraform isn't initialized**
Symptom: `tailscale-manager.service` fails with `✗ Terraform is not initialized. Run 'tailscale-manager init' first.` on first deployment. Root cause: The upstream NixOS module only writes policy/auth-key files in `ExecStartPre` but never runs `tailscale-manager init` to set up the Terraform workspace (`.terraform/`). The `apply` command refuses to proceed if the workspace doesn't exist. Fix: The local `modules/nixos/tailscale/config.nix` adds `preStart = "${config.services.tailscale-manager.package}/bin/tailscale-manager init"` which injects an `ExecStartPre` entry that runs init before apply. This is merged with the upstream's existing `ExecStartPre` entries via NixOS's `unitOption` merge (lists are concatenated). On an already-broken system, also run `sudo tailscale-manager init` manually in `/var/lib/tailscale-manager/` to initialize the existing state dir.

**`tailscale-manager` structured policy serialization includes empty nested fields, breaking Tailscale API**
Symptom: `tailscale-manager.service` fails with `json: unknown field "appConnectors" (400)` after migrating to `services.tailscale-manager.policy` structured options. Cause: The upstream v0.3.2 `policyToJSON` uses shallow `lib.filterAttrs` that only cleans top-level keys. Empty submodule defaults like `autoApprovers = { appConnectors = []; exitNode = []; routes = {}; }` pass through, and Tailscale's API rejects `appConnectors` when it's not yet supported or recognized. Fix: Use the raw `services.tailscale-manager.acl.policy` string instead of structured `policy.*` options. The raw string passes through without serialization and avoids the nested-defaults issue.

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
Fix: Use conditional guards: `someService.enable = config.age.secrets ? "cache-token";` or check with `lib.optionalAttrs (config.age.secrets ? "cache-token")`. The `agenixManager.enable` flag is set to `false` in CI (`modules/flake-parts/packages.nix`) - all secret consumers should guard with `?` or `agenixManager.enable`.

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
Fix: Ensure `nixosModules.common` is imported (it brings in the profile system). Check that the profile exists in `modules/nixos/profiles/system/`.

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

**Installer ISO copy to Ventoy USB silently corrupts 1.5GB squashfs**
Symptom: ISO boots via Ventoy but fails with `fsconfig() failed: unable to read id index table`. The file size on the USB matches the store, and the first 10MB are identical, but the last 10MB differ (MD5 mismatch). Cause: The deploy script's `cp` to exfat silently corrupted the tail of the 1.5GB file. The `deploy_isos()` function uses hash-based `.deploy-state` tracking to verify copies, but the installer ISO was deployed by a separate code path (`deploy_installer_iso()`) that used plain `cp` with no checksum verification. Fix: Added SHA-256 integrity verification after every installer ISO copy with automatic retry. The fix is in `modules/flake-parts/ventoy/deploy-script/ventoy-deploy.sh` — the `cp` is now followed by `sha256sum` comparison of source and destination. On mismatch it deletes and retries once; if still mismatched, it exits with error. Always verify manually with `sha256sum $STORE_ISO $USB_ISO` before booting the target machine.

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






**Answer file XML refactor — templates moved to packages/ventoy/answer-files/**
Symptom: Changes to Windows unattended answer XML aren't reflected after rebuild. Cause: The answer file XML was extracted from inline Nix strings to standalone `packages/ventoy/answer-files/{dev,minimal,domain,kiosk,dual-boot}.xml` templates with `@VAR@` placeholders. The `buildAnswer` function now uses `pkgs.substituteAll` instead of `pkgs.runCommand` with heredocs. Fix: Edit the `.xml` files directly. The `@VAR@` placeholders are substituted from the Nix `answerFileConfigs` and `answerFileSettings`. The product key (`VK7JG-NPHTM-C97JM-9MPGT-3V66T`) is still hardcoded in `answer-files.nix`.


---


---

**Nginx location collision between proxy services — `^~` prefix with longest-match wins for sequence-distinguishable paths**
Symptom: RisuAI SPA fails to load at `/risuai/`. Browser receives Open WebUI's HTML instead of RisuAI's JS/CSS/API responses. Cause: Two proxy upstreams (RisuaAI, Open WebUI) register `extraLocations` targeting the same root-absolute paths (`/assets/`, `/api/`). Open WebUI uses a regex `~ ^/(_app|static|api|ws|assets|auth|error|s/|watch)($|/)` which, per nginx precedence, beats plain prefix locations regardless of config order. Fix: Use `^~` modifier on prefix locations to make them immune to regex matches. For `/assets/`: only RisuAI uses it — add `^~` to RisuAI's `/assets/` location. For `/api/`: RisuAI uses bare `/api/*` (`/api/read`, `/api/write`, etc.) while Open WebUI uses `/api/v1/*` — these are sequence-distinguishable at the second segment. Add `^~ /api/v1/` to OWUI's extraLocations and `^~ /api/` to RisuAI's extraLocations; nginx's longest-prefix-win for `^~` routes `/api/v1/*` → OWUI and `/api/*` → RisuAI correctly. Only a true same-length collision (both services wanting identical path) would require sub_filter or path rewriting. See `modules/nixos/risuai/config.nix:62-82` and `modules/nixos/open-webui/config.nix:76-90`.

---

**Moku "could not reach server" despite browser/curl working — Tauri webview fetch vs curl**
Symptom: Moku (Tauri app) shows "Could not reach server..." even though `curl` and the browser both reach `https://server.tail685690.ts.net/suwayomi/` fine. Cause: The Tauri webview uses WebKitGTK which has its own TLS certificate store, CORS enforcement, and fetch semantics that can differ from curl/browser. Specifically: (1) WebKitGTK may not trust the Tailscale CA if it's absent from the NSS/system trust store — Tailscale adds its CA to the system store via `tailscaled`, but WebKitGTK's GnuTLS backend may use a different trust chain. (2) Even though suwayomi returns `Access-Control-Allow-Origin: tauri://localhost` for CORS, WebKitGTK may reject non-standard `tauri://` scheme origins in CORS preflight checks. (3) The `substituteInPlace` URL is baked at build time — verify with `nix log $(nix-store -q --outputs /run/current-system | grep moku)` to check the build log. **Debug steps:**
1. `curl -X POST "https://server.tail685690.ts.net/suwayomi/api/graphql" -H "Content-Type: application/json" -d '{"query":"{ aboutServer { name } }"}'` — confirms the path-based API works
2. `curl -X OPTIONS "https://server.tail685690.ts.net/suwayomi/api/graphql" -H "Origin: tauri://localhost" -H "Access-Control-Request-Method: POST" -D-` — check CORS preflight
3. `strings /nix/store/$(readlink -f $(which moku) | grep -o 'nix/store/[^/]*')/bin/..moku-wrapped-wrapped | grep -c "server.tail\|4567\|suwayomi"` — verify baked URL exists in binary
4. `cat ~/.local/share/io.github.MokuProject.Moku/credentials.json` — check persisted server URL credential
5. `cat ~/.local/share/io.github.MokuProject.Moku/settings.json` — check persisted autoStartServer setting
6. `rm -f ~/.local/share/io.github.MokuProject.Moku/{credentials,settings}.json` — clear stale state
7. If still failing, switch to plain HTTP over Tailscale IP (bypasses TLS and Caddy path-routing): set `my.programs.moku.serverUrl = "http://<tailscale-ip>:4567"` and ensure `autoBindTailscaleIp = true` on the server.

See `modules/nixos/moku.nix` for the `substituteInPlace` build-time URL injection.
See `configurations/nixos/desktop/default.nix` for the host-level `serverUrl` config.

---

**Dashboard/proxy upstream host mismatch — Caddy `reverse_proxy` points at wrong IP**
Symptom: Dashboard at `https://server.tail685690.ts.net/` loads but a service tile (e.g. Suwayomi) returns 502 or connection refused. The service's own URL (`https://server.tail685690.ts.net/suwayomi/`) also times out. Cause: The service binds to a non-loopback IP (e.g. Tailscale IP via `autoBindTailscaleIp`) but Caddy's upstream `host` defaults to `127.0.0.1`. The module registers the upstream with only `port` and `path`, leaving `host` at the default `"127.0.0.1"`. When the service binds elsewhere (Tailscale IP, separate interface, etc.), Caddy can't connect. **Debug steps:**
1. `ss -tlnp | grep <port>` — check what address the service actually binds to
2. `cat /etc/caddy/caddy_config | grep reverse_proxy` — check what host:port Caddy is proxying to
3. If the bind IP != the proxy target, override: `my.services.proxy.upstreams.<name>.host = "<correct-ip>";`
4. Verify after rebuild: `nix eval .#nixosConfigurations.server.config.my.services.proxy.upstreams.<name>.host`
5. Check if the override was deployed: `ssh server tail685690.ts.net "cat /etc/caddy/caddy_config | grep <name>"`

The proxy module now emits an eval-time warning when suwayomi has `autoBindTailscaleIp` enabled but the upstream host is still `127.0.0.1`. See `modules/nixos/proxy/tests.nix`.

---

**Nix eval shows correct config but deployed Caddyfile is stale — git push + redeploy required**
Symptom: `nix eval .#nixosConfigurations.server.config.my.services.proxy.upstreams` shows the correct host override, but `/etc/caddy/caddy_config` on the server still has the old value. Cause: Local changes were evaluated by `nix eval` (which reads the local filesystem) but never committed/pushed to the git remote. The server's `nix run .#activate` pulls from the remote, not from your local working tree. Fix: `git add -A && git commit -m "..." && git push` then `ssh server.tail685690.ts.net "cd ~/nixos-config && git pull && nix run .#activate"`.

Last updated: 2026-07-23
