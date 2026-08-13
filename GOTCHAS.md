# GOTCHAS.md — Known Footguns and Fixes

> Living log of problems that have caused failures or wasted
  cycles.> **Check
  this
  before
  debugging
  any evaluation or build
  failure.**

**`just` runs each recipe line in a separate shell — a `cd` on one line does not persist to the next**

Symptom (2026-08-13): `just packwiz testModpack init` (recipe: `cd modules/…/testModpack` then `nix run "…/nixos-config#packwiz" -- init`) ran packwiz from the **repo root** — the interactive default name showed "Nixos Config" (the git repo name) instead of "testModpack", and init failed mid-"Refreshing index" with `read result: is a directory`, leaving a stray 0-byte `index.toml` in the repo root. Cause: `just` executes each recipe line in its own shell, so `cd` on line 1 has no effect on line 2; packwiz (which operates on CWD) therefore ran in the repo root and choked on the repo's directory structure. Fix: chain on one line — `cd … && nix run … -- …` — or use a shebang recipe. Same applies to any multi-line `just` recipe that relies on a directory change.

---

**`packwiz refresh` indexes `checksums.json` at the pack root — breaking index.toml sync (index 256 vs 255 mods) unless `.packwizignore` excludes it**

Symptom (2026-08-13): After adding `[options] datapack-folder = "config/paxi/datapacks"` to `testModpack/pack.toml` and running `packwiz refresh`, `mc-pack-status` reported `index.toml entries: 256 (MISMATCH)` while only 255 mods exist. Cause: packwiz indexes **every file** in the pack dir, and `checksums.json` (a Nix-side build artifact that lives at the pack root for packwiz2nix) is not in the default ignore list — so `refresh` added it as an internal file, and installers would have copied it into the game folder. Fix: add a `.packwizignore` (gitignore-format) at the pack root containing `checksums.json`. Re-run `packwiz refresh` → back to 255 in sync. Any other pack-root artifact (exported zips, etc.) needs the same treatment. See `modules/nixos/minecraft-server/modpacks/testModpack/.packwizignore`.

---

**packwiz internal files (configs, datapacks, kubejs/scripts) are indexed but never reach the server unless the module symlinks them — mods only come from checksums.json**

Symptom (2026-08-13): The `servers.<name>.packwiz` path built every mod jar via packwiz2nix (`mkModLinks`) but **nothing else** — a pack shipping `config/<mod>/…` default configs or `config/paxi/datapacks/…` patches had them silently absent from the server's data dir. Cause: the packwiz deploy path only consumed `checksums.json` (mod jars); internal files are a separate packwiz concept that packwiz-installer copies on client install, and our Nix server had no equivalent. Fix: the module now symlinks the pack's `config/`, `kubejs/`, `scripts/`, `datapacks/`, `defaultconfigs/` subdirs into the data dir at start (`packwizStartPre` in `modules/nixos/minecraft-server/config.nix`, wired into `extraStartPre`) — `mods` is excluded since jars come from checksums.json. Verify with `mc-pack-status` (it now checks that every on-disk internal file is in index.toml and that Paxi datapack pack_formats match the pack's MC version; 1.21.1 = 48). Related: `config-preserve`/`config-add`/`datapack-add` opencode tools live in `modules/nixos/minecraft-server/opencode/tools/mc-pack.py` — every file edit must `packwiz refresh` or the file is on disk but unindexed (never installed).

---

**`error: The option 'my.<name>' does not exist` — new module never imported into a host config**

Symptom (2026-08-12): Created `modules/nixos/remote-gui/` (meta/options/config/services/tests), then `nix eval .#nixosConfigurations.server.config.my.services.remoteGui` failed with `error: The option 'my.services.remoteGui' does not exist. Did you mean 'my.services.comfyui' ...`. Cause: autowiring only exports the module as a flake output (`nixosModules.remote-gui`) — it does **not** import it into any NixOS configuration. Hosts get options only from the modules listed in `modules/nixos/common.nix` imports (which every host imports), so a brand-new module's options are invisible until you add `./<name>` there. Fix: add `./remote-gui` to `modules/nixos/common.nix` imports, then `git add` the new dir (see the untracked-files entry below — pure flake eval only sees git-tracked paths) before eval/`flake check`. Confirmed working: submodule option defaults may reference `flake.config.me.username` (e.g. `default = flake.config.me.username` inside a `types.submodule`).

---

**`error: dynamic attribute 'seanc' already defined` when adding a second `home-manager.users.${username}.my.programs.X` line in one profile**

Symptom (2026-08-08): Adding `home-manager.users.${username}.my.programs.minecraft.enable = lib.mkDefault true;` as a sibling of the existing `home-manager.users.${username}.my.programs.discord.tui = { ... };` in `modules/nixos/profiles/system/gaming.nix` fails with `error: dynamic attribute 'seanc' already defined at .../gaming.nix:15:5` / `at .../gaming.nix:23:5`. Cause: in Nix an attrset literal can only assign a given dynamic attribute (`users.${username}`) once, so two `home-manager.users.${username}.my.programs.<name>` lines collide at parse time. Fix: merge them into a single block — `home-manager.users.${username}.my.programs = { minecraft.enable = lib.mkDefault true; discord.tui = { enable = lib.mkDefault false; }; };` — the module system merges the sub-paths fine.

**nix-minecraft: module is `nixosModules.minecraft-servers` (plural) and options are `services.minecraft-servers.servers.<name>` (plural) — no `extraServiceConfig`**

Symptom (2026-08-12): Wiring nix-minecraft into the `my.services.minecraftServer` wrapper, two names were easy to get wrong. (1) The flake exposes `nixosModules.minecraft-servers` (plural "servers"), not `minecraft-server`; the option tree is `services.minecraft-servers.servers.<name>` (both plural). (2) The server submodule has NO `extraServiceConfig`/`extraSystemd` option — a host config that sets `services.minecraft-servers.servers.<name>.extraServiceConfig.MemoryMax = "12G"` fails with `Did you mean ...extraReload / extraStartPre?`. Cause: nix-minecraft hardens the unit internally (its own `serviceConfig` is derived in the module, `modules/minecraft-servers.nix` ~line 948/998) and does not forward arbitrary systemd fields. Fix: augment the generated unit directly at the NixOS level — `systemd.services.minecraft-server-<name>.serviceConfig.MemoryMax = "12G"`. Also note `dataDir` is a `types.path` (must exist / be coercible at eval time); for big local modpacks point `pack` at a plain string runtime path and create symlinks in `extraStartPre` (nix-minecraft appends it to `ExecStartPre`), NOT via `symlinks` (which copies into the store). See `modules/nixos/minecraft-server/`.

---

**nix-minecraft `managementSystem` is kebab-case (`systemd-socket`); our wrapper option is camelCase — pass-through silently breaks systemd-socket mode**

Symptom (2026-08-12): The `my.services.minecraftServer` wrapper declared `managementSystem.systemdSocket.enable` (camelCase) and forwarded it verbatim with `inherit (srv) managementSystem` into `services.minecraft-servers`. But nix-minecraft's submodule option is `managementSystem."systemd-socket".enable` (kebab). Result: tmux mode worked (names happen to match), but `systemdSocket.enable = true` set an undeclared option path → eval error, so the (recommended) FIFO+journald console was unreachable. Fix: translate camelCase → kebab when building the nix-minecraft attrset (`mkManagement` in `modules/nixos/minecraft-server/config.nix`). Related: the web console (`mc-web-<name>`) REQUIRES systemd-socket management — there's no FIFO to write under tmux. Assertion in `tests.nix` guards this.

**Prism Launcher gitignores `mods/` — a git-repo-synced instance has config text but no mod jars**

Symptom (2026-08-12): Pointing a server at `rootDir`/`instance` from the synced Prism repo yields a working config/kubejs/datapacks layout but an EMPTY `mods/` dir — the repo's `.gitignore` excludes `instances/*/minecraft/mods/` (jars are re-downloadable; the repo only commits `mods.manifest` name+sha1+size listings). The desktop `mrpack/modrinth.index.json` is also stale (base managed pack only, e.g. 55 files vs 229 real mods).

Resolution (2026-08-12, same day): `rootDir`/`instance` were removed from the module entirely — the git-repo-sync approach was replaced by **zip-drop provisioning**. Export the pack from Prism ("Export → Modrinth pack", `.mrpack` is just a zip) and scp it to `packDir`; the server sets `servers.<name>.packZip = "dragon-technology.mrpack"` and unpacks it into the data dir when the zip's SHA-256 changes. The `.mrpack`'s index is small (URL+sha512+env references) but does NOT bundle jars the way a full export zip does — for a fully self-contained drop, zip the instance's `minecraft/` folder instead (the module detects a top-level `minecraft/`). See "Provisioning mods with packZip" in `modules/nixos/minecraft-server/README.md`.

---

**systemd-tmpfiles silently refuses to create paths under a non-root-owned parent ("unsafe path transition") — minecraft-server fails with status=200/CHDIR**

Symptom (2026-08-12): Deploying the `my.services.minecraftServer` module with `dataDir = "/mnt/data/minecraft"` made `minecraft-server-dragon-technology.service` fail on start: `ExecStartPre ... status=200/CHDIR`, `Dependency failed`, and the `.socket` hitting `start-limit-hit`. Root cause: nix-minecraft creates each server's `WorkingDirectory` (`${dataDir}/<name>`) via a **tmpfiles rule**, but `systemd-tmpfiles` detects `/mnt/data` (owned by the primary user `seanc`, not root) and skips the rule with `Detected unsafe path transition /mnt/data (owned by seanc) → /mnt/data/minecraft`. The data dir never gets created, so systemd cannot `chdir` into it. Fix (module): a root oneshot `minecraft-server-prepare-dirs` (`Before=` every server unit) that `install -d`s `dataDir` + each `<name>` subdir as `minecraft:minecraft 0770` — tmpfiles is the wrong tool whenever a data path passes through a user-owned mount point like `/mnt/data`. See `modules/nixos/minecraft-server/config.nix`. Related: `packDir` must also be user-accessible — the module adds the primary user to the `minecraft` group (dataDir is `0770 minecraft:minecraft`, so without membership the user cannot traverse it to scp zips).

---

---

**Some repo files are root-owned (`configurations/nixos/desktop/default.nix`, `GOTCHAS.md`) — Edit/write tools fail with `PermissionDenied`**

Symptom (2026-08-08): The Edit tool refused to modify `configurations/nixos/desktop/default.nix` and `GOTCHAS.md` (`FileSystem.writeFile: PermissionDenied`) even though the repo dir and most files are `seanc`-owned. Cause: those files are `-rw-r--r-- root root` (unlike `modules/…`, `HEATMAP.md` which are all `seanc`). Fix: edit a temp copy owned by your user (`cp` → `chown seanc:users` → Edit) then `sudo install -m 644 -o root -g root <tmp> <target>` to preserve ownership, and confirm with `stat`. Related to the existing `tools/nix-graph/` root-owned-files gotcha — these were likely written by a root deploy.

---

**restic Prometheus exporter crash-loops forever (`KeyError: 'check_success'`) when the monitored repo is uninitialized**

Symptom (2026-08-12): on the backup-target host, `prometheus-restic-exporter.service` is stuck in `activating (auto-restart)` with `status=1/FAILURE`, and the journal shows a `KeyError: 'check_success'` traceback from restic-exporter.py. Cause: the exporter crashes at startup when the repository has no `config` file (never initialized). The config's "self-heal" (`Restart=on-failure`, `RestartSec=10min` in `modules/nixos/backup-target/config.nix`) only heals if the first source host's backup actually runs `restic init` — if that host's *deployed* generation predates the backup-source config (or lacks the `backup-repo-passphrase`/`backup-ssh-key` secrets), the repo is never initialized and the loop never heals. Fix: initialize the repo server-side as the backup user — `sudo -u backup env RESTIC_PASSWORD="$(sudo cat /run/agenix/backup-repo-passphrase)" nix-shell -p restic --run 'restic -r /mnt/data/backup/<host> init'`, then `systemctl restart prometheus-restic-exporter.service`. Source-side `initialize = true` against an existing repo is a no-op, so this is compatible. Also: `StartLimitIntervalSec` is a `[Unit]` key — putting it in `serviceConfig` gets silently ignored with `Unknown key 'StartLimitIntervalSec' in section [Service]` (fixed 2026-08-12 to `unitConfig`).

---

**Ollama Modelfile `PARAMETER think` is rejected — `ollama create` fails with `unknown parameter 'think'`**

Symptom: Setting `think = true` on a model in `my.services.ollama.models` (the ollama module's `think` option, `modules/nixos/ollama/options.nix:48`) makes `ollama-pull-models` fail and the derived model never gets created, so downstream generation fails with model-not-found. Cause: Ollama's `think` is a **request-level** field of `ChatRequest` (boolean or `"low"/"medium"/"high"/"max"`), NOT a member of `Options` — and Modelfile `PARAMETER` lines are validated against the `Options` struct's json tags via `FormatParams` (`api/types.go`), which returns `unknown parameter 'think'` and aborts `ollama create`. Fix: never set the module's `think` option; control thinking from the client instead. For RisuAI that means the UI setting `ollamaThinkingMode` (which sends request-level `think`), enforced server-side via `my.services.risuai.settings`. Note the module option is a latent footgun: models use `freeformType = attrsOf anything`, so simply deleting the option declaration would not stop `services.nix` from still emitting the PARAMETER line.

---

**Root-owned `.git/objects/xx` subdirs (from a root-run auto-commit) block `git add` — `insufficient permission for adding an object to repository database .git/objects`**

Symptom (2026-08-08): `git add`/`git commit` fail with `error: insufficient permission for adding an object to repository database .git/objects`, and the working tree has root-owned `.git/objects/<xx>/` subdirectories (check: `find .git/objects -maxdepth 1 -not -user $(whoami)`). Cause: a git process running as root (e.g. the `suwayomi-sync-export` auto-commit service, which runs as root and commits at midnight) creates `.git/objects` subdirs owned by root; a non-root user then cannot write new objects into them. Distinct from the `tools/nix-graph/*.json` entry — this is the object store itself, and it breaks `git add` rather than `git pull`/`checkout`. Fix: `sudo chown -R seanc:users .git/objects/<xx> .git/objects/<yy>` (the specific root-owned subdirs), then re-run the failed git command. Recurrence is expected until the root-run auto-commit is taught to preserve ownership (`sudo -u seanc git commit` or a `git config core.sharedRepository` arrangement).

---

**Root-owned files in the repo tree (`tools/nix-graph/*.json`) block `git pull`/`checkout` — `error: unable to unlink old '…': Permission denied`**

Symptom (2026-08-06): Running `git pull`/`git checkout` after `git fetch` fails with `error: unable to unlink old 'tools/nix-graph/graph.json': Permission denied`, leaving the branch behind its remote and the file showing as `M` (modified) even though you never edited it. `tools/nix-graph/` contains root-owned files (`graph.json` tracked, `extraction-result.json` untracked, dir owned by root) — the nix-graph MCP server writes them as root. Cause: root-owned paths in the working tree make git's unlink/rewrite fail for a non-root user; a stale root-written copy then diverges from the committed version and shows as a spurious modification. Fix: `sudo rm -f tools/nix-graph/graph.json tools/nix-graph/extraction-result.json`, fix the directory ownership (`sudo chown seanc:users tools/nix-graph`), then `git checkout -- tools/nix-graph/graph.json`. If the dir was already root-owned the `rm` may also fail — chown the dir first. Also check `git worktree list` before cleanup: stale worktrees pin branches (delete them with `git worktree remove --force` before `git branch -D`).

---

**Concurrent
  opencode
  sessions
  (browser + terminal)
  share
  one
  state
  dir
  and
  corrupt
  the
  ensemble —
  gate with a PID lock**

Symptom: running `nix-refine` from the opencode web (browser) session breaks team orchestration — teammates won't spawn, or `team_create`/`team_spawn` hang or fight. Cause: both `opencode web` (systemd `opencode-web-*.service`) and a terminal `opencode` run as the same user, so they share `~/.config/opencode/ensemble.db` (SQLite) and `~/.local/share/opencode/opencode-stable.db` (multi-hundred-MB). Two processes holding the DB + ensemble dashboard port 4747 → the plugin flags one as a `stale-server` and `team_*` state diverges. Also the web service OOM-killed the host twice when a team was spawned from the browser (teammates run in the service's cgroup). Fix (2026-08-04): `my.services.opencodeWeb.sessionGate` (default on) adds an `ExecStartPre` to each web unit that refuses to start while a terminal session's PID lock (`~/.local/share/opencode/terminal.lock`) is alive, clearing stale locks; `my.programs.opencode.sessionGate` (default off; enabled on `server`) wraps the terminal `opencode` binary to refuse to start while any `opencode-web-*.service` is active and to write the PID lock. `OPENCODE_ALLOW_CONCURRENT=1` bypasses both. `MemoryHigh`/`MemoryMax` (defaults 4G/8G) cap the web service cgroup so a runaway team can't OOM the host. Stale-worktree aftermath of a crashed run is cleaned with `git worktree list` + `git worktree remove --force`.

---

**`opencode web` 1.16.2 UI crashes with "Settings context must be used within a context provider" — every browser interaction (incl. permission prompts) fails**

Symptom: In the browser UI, the home screen and session views render a global error boundary (`Something went wrong`) with `Error: Settings context must be used within a context provider` / `ServerSync context must be used within a context provider` (stack: `use` in `index-*.js`, `Fr` in `home-*.js`). Permission requests, project picker, and session list all fail because the app never mounts. Cause: an upstream opencode web frontend regression (anomalyco/opencode#30478, reported for 1.15.13, still present in 1.16.2). Reproduces with an empty config and `OPENCODE_PURE=1` (all plugins off) and survives a full site-data wipe — it is NOT stale browser cache. Fix (2026-08-05): the flake's nixpkgs pins opencode 1.16.2; bumping nixpkgs to get the fix is a ~2-month package-set jump, so `overlays/default.nix` overrides `opencode` to `packages/opencode` (the official v1.18.13 linux-x64 release binary, verified to render the home screen). Build gotchas: the release tarball is a bare `opencode` file (use `dontUnpack` + `tar -xOzf`), and `dontStrip = true` is REQUIRED — `strip` corrupts the bun-compiled single-file binary (wrong `--version`, "Script not found web"). Remember to `git add` new files before `nix eval` (flakes only see git-tracked paths).

**Browser sessions go blank / no messages sendable after a browser-side nix-refine run — systemd-oomd killed the whole web unit on swap pressure, not a data problem**

Symptom (2026-08-05): After running `nix-refine` from the opencode **web** session, the browser UI shows black/blank session views and new messages can't be sent. The session data is intact — `~/.local/share/opencode/opencode.db` verifies with `PRAGMA integrity_check` = ok and the session's 66 messages / 259 parts all parse — so it is NOT corruption. Cause: `systemd-oomd` (active, `/etc/systemd/oomd.conf` has `SwapUsedLimit=90%`) OOM-killed the *entire* `opencode-web-nix-config.service` unit when the ensemble team (all processes share the unit cgroup) spiked to ~4.3G memory + 5.8G swap (journal: `systemd-oomd killed 24 process(es) in this unit`). Killing the whole cgroup takes down the web server, so the frontend renders nothing and can't submit. The `MemoryHigh`/`MemoryMax` cgroup caps alone don't help — they bound RAM, not swap, so oomd's swap policy (a whole-unit kill) fires first. Fix (2026-08-05): `modules/nixos/opencode-web/` now sets `MemorySwapMax` (default `4G`) and opts each unit out of oomd wholesale kills via `ManagedOOMMemoryPressure = "never"` + `ManagedOOMSwap = "never"`. Degradation then falls to the kernel cgroup OOM-killer, which kills **one teammate at a time** (the largest member) instead of the web server — the browser session survives memory pressure. Verify with `nix eval .#nixosConfigurations.<host>.config.systemd.services.opencode-web-<name>.serviceConfig` → `ManagedOOMMemoryPressure`/`ManagedOOMSwap`/`MemorySwapMax` present. Diagnosis checklist: `journalctl -u opencode-web-nix-config.service --since yesterday | grep -i oom`; `sqlite3` `PRAGMA integrity_check` on both `opencode.db` and `opencode-stable.db`.

**Ensemble teammates spawn without a worktree — `git` missing from the `opencode-web-*.service` PATH**

Symptom: Every ensemble `team_spawn` with `worktree=true` logs `service=ensemble spawn:worktree:failed err=[object Object]` (immediately after `spawn:worktree:start`, ~5ms) and the teammate runs in the main directory. Cause: the systemd unit's `Environment=PATH=` is the NixOS default systemd path (`coreutils:findutils:gnugrep:gnused:systemd`) — no `git`. opencode's `Worktree` service shells out via `ChildProcess.make("git", ...)` (`packages/opencode/src/worktree/index.ts`), so worktree creation fails ENOENT; the bash tool works because it spawns zsh which re-sources the full user PATH. Same root cause as the startup `Executable not found in $PATH: "xdg-open"`. Fix: add a top-level `path = with pkgs; [ git bash coreutils findutils gnugrep gnused systemd ];` to the service in `modules/nixos/opencode-web/config.nix` — a TOP-LEVEL key, not `serviceConfig.path` (that key is silently ignored, see the `serviceConfig.path` gotcha below). Verify with `nix eval .#nixosConfigurations.<host>.config.systemd.services.opencode-web-<name>.environment.PATH`.

---

**Caddy env placeholders are `{$VAR}`, not shell-style `${VAR}` — Nix `\${` escaping produces the wrong order**

Symptom: Caddyfile has `header_up Authorization "${OPENCODE_WEB_BASIC_AUTH}"` and the backend still returns 401; `curl http://localhost:2019/config/` shows the running config with the literal `"${OPENCODE_WEB_BASIC_AUTH}"` even though the env var is set in the caddy process (check via `sudo cat /proc/<pid>/environ`). Cause: Caddy's env substitution is `{$ENV_VAR}` (curly-brace, *then* `$`), but the natural Nix write `"header_up Authorization \"\${${i.apiAuthEnv}}\""` renders `${OPENCODE_WEB_BASIC_AUTH}` — a shell-style placeholder Caddy ignores. The two renderings are visually near-identical; only `hexdump -C` shows the byte-order difference (`"${` vs `"{$`). Fix: emit `{` *before* the escaped `$`: `"header_up Authorization \"{\$${i.apiAuthEnv}}\""` → `{$OPENCODE_WEB_BASIC_AUTH}`. Verify by `caddy adapt` with the env var exported and grepping the adapted JSON. Hit while wiring basic-auth injection for the dashboard's opencode session API (`modules/nixos/proxy/config.nix`). Related: `header_up` is a `reverse_proxy` *sub-directive* — it must be nested inside `reverse_proxy host:port { … }`, not a sibling, or Caddy fails with `unrecognized directive: header_up` while parsing `handle_path`.

---

**`lib.optional cond "a" + "b"` parses as `(lib.optional cond "a") + "b"` → "cannot coerce a list to a string"**

Symptom: `nixos-rebuild` / eval fails with `error: cannot coerce a list to a string: [ "..." ]` where the offending list is the *first* half of a multi-part warning/assertion message built with string concatenation. Cause: Nix function application binds tighter than `+`, so `lib.optional cond "part1" + "part2"` is `(lib.optional cond "part1") + "part2"` — a list plus a string. Fix: parenthesise the concatenation: `lib.optional cond ("part1" + "part2")`. Same applies to any `lib.optional`/`lib.optionalString`/`lib.mkIf` whose value is built with `+`. Hit while adding a `warnings` entry to `modules/nixos/opencode-web/tests.nix`.

---

**`lib.optionalString` returns a *string* — do not `++` it into a list → "expected a list but found a string: \"\""**

Symptom: eval fails with `error: expected a list but found a string: ""` (or the empty-string value of the false branch), e.g. while building a CLI arg list in a home module: `concatStringsSep " " ((optionalString cond "-passwd /x") ++ otherArgs)`. Cause: `lib.optionalString cond str` returns a **string** ("" or the arg), but `++` is **list** concatenation — so string `++` list is a type error (and two `optionalString` results `++`'d together also fail once one is ""). Fix: use `lib.optionals` (plural) which returns a list of zero-or-one strings: `(optionals cond [ "-passwd /x" ]) ++ otherArgs`, then `concatStringsSep " "` the whole list (filter out `""` first if any branch can add empties). Verified while building `modules/home/vncviewer/config.nix` (2026-08-13); the existing `lib.optional` entry above covers the `+`/list direction, this covers the `optionalString`/`++` direction.

---

**`opencode web`/`serve` headless gotchas — browser-open, SPA subpaths, `lib.getExe`, no base64 builtin**

Symptom: Building a systemd service for `opencode web` hits 203/EXEC, or the dashboard links don't work, or the web UI breaks when proxied under a subpath. Cause/fix (all verified while building `modules/nixos/opencode-web/`): (1) **Multi-project server** — `opencode web`/`serve` loads instances per-request via the `x-opencode-directory` header and defaults to `process.cwd()`, so a service should run with `WorkingDirectory` = the repo checkout (per-repo session scoping, and the web UI opens that repo by default). (2) **Browser-open is best-effort** — the `web` command calls `open(localhostUrl).catch(() => {})`, which is safe headless, but set `BROWSER=/bin/true` in the unit env so the `open` npm package execs a no-op instead of trying `xdg-open`. (3) **SPA cannot be subpath-proxied** — the web app's Vite build has no `base`, so asset URLs are root-absolute (`/assets/...`); serving it behind Caddy at `/opencode/<name>/` breaks. Link directly to `http://host:port/`; proxy only the API (`/session`, `/event`, …) via a `handle_path /opencode-api/<name>/*` → backend for same-origin dashboard fetches. (4) **`lib.getExe` on a `symlinkJoin`** (e.g. `opencode-wrapped`) resolves `bin/opencode-wrapped`, which doesn't exist — `symlinkJoin` preserves the real binary name `bin/opencode` and doesn't set `meta.mainProgram`; use the explicit `${pkg}/bin/opencode` in `ExecStart`. (5) **No base64 builtin** — this repo's Nix has neither `builtins.base64Encode` nor `lib.strings.toBase64`; compute the base64-encoded project dir for session deep-links (`/<base64(dir)>/session/<id>`) in the dashboard with the browser's `btoa()`. (6) **Session API** — `GET /session` returns sessions for the instance's directory (cwd) when no `x-opencode-directory` header is sent; response shape is defensive-checked (`Array.isArray(d) ? d : (d.sessions || d.data || [])`). (7) **Tailnet access via `tailscale serve --https <port>`** — modern Tailscale (≥1.52) supports *arbitrary* `--https` ports (verified 8443 and 12345), so each repo gets its own tailnet HTTPS URL `https://<host>.ts.net:<port>/` without touching the Caddy `:443` serve rule. Expose with a `Type=oneshot` + `RemainAfterExit` unit: `ExecStart = tailscale serve --bg --https <port> http://127.0.0.1:<backend>`, `ExecStop = tailscale serve --https <port> off`, with a `while ! tailscale status | grep -q .` `ExecStartPre` wait. The dashboard builds links from `window.location.hostname` (`https://<host>:<servePort>/`) and falls back to the direct local URL for `localhost` — no tailnet DNS suffix is needed at eval time. Emit a `warnings` entry when tailnet serve is enabled without a `passwordFile` (tailnet nodes could use the user's API keys otherwise).

---

**SSH sessions die ~hourly with "context canceled" — tailscale-watchdog false-positives and restarts tailscaled**

Symptom: Long-lived Tailscale SSH sessions (opencode / ensemble workloads, or any session that stays open) drop every ~60 minutes. `journalctl -u tailscaled` shows `ssh-session(sess-…): terminating SSH session from <ip>: context canceled` then `Wait: code=-1` at the exact minute `systemd[1]: Stopping/Starting Tailscale node agent...` runs (restarts observed at 02:32/03:33/04:37/05:38…). Cause: tailscaled *is* the Tailscale SSH server, so every restart kills all active sessions. The restarts are triggered by `tailscale-watchdog.service` (`autoRepair`): its probe ran `ip link show dev tailscale0 | grep -q "state UP"`, but `tailscale0` is a TUN device with no carrier that always reports `state UNKNOWN`, so the probe false-positives on every single run — the 1h `alertCooldown` is what throttles the restart to ~hourly. Compounding bug: the alert email never sent because `send-alert` lives in `/run/current-system/sw/bin` (installed by the email-alerts module's `systemPackages`), which is absent from the systemd service PATH — watchdog logs `send-alert: command not found` at line 16 whenever it tries to alert. Fix (`modules/nixos/tailscale-watchdog/config.nix`): (1) probe the IFF_UP flag instead of operstate — `[[ $(($(cat /sys/class/net/tailscale0/flags 2>/dev/null || echo 0) & 1)) -ne 1 ]]` (must use `cat`, not `$(< file)`, which trips shellcheck SC2188 in `writeShellApplication`); (2) `export PATH="/run/current-system/sw/bin:$PATH"` at the top of the script so `send-alert` resolves. Diagnose fast: `systemctl list-timers | grep tailscale-watchdog`, then correlate watchdog runs with tailscaled restarts in `journalctl -u tailscaled`; a healthy probe right now still shows `state UNKNOWN` on `tailscale0` — that's normal, don't "fix" it.

---

**`mkForce` is used in more places than GOTCHAS documents — grep before overriding**

Symptom: overriding an option with a plain assignment silently loses to a `lib.mkForce` elsewhere, or adding a host-level assignment conflicts with one. Cause: mkForce sites beyond the documented ones. Verified current sites: modules/nixos/tailscale/config.nix:24 (`environment.etc."resolv.conf".source = lib.mkForce`), modules/nixos/bluetooth.nix:37 (`CapabilityBoundingSet`), configurations/nixos/desktop/default.nix:24-45 (my.vm.extraConfig VM-variant overrides), modules/nixos/ai/comfyui/config.nix:92,112,113, modules/nixos/homeManager/config.nix:46-54 (agenix owner/group), modules/nixos/disko/config.nix:111,116, modules/flake-parts/packages.nix:23-24, modules/flake-parts/test-runner.nix:15-16, modules/flake-parts/vm/config.nix:44-45,48, modules/flake-parts/live-iso/config.nix:88,103, modules/nixos/common.nix:208,228 (system.activationScripts.agenixManagerSecretsNix .text/.deps), modules/nixos/zerotier/config.nix:24. Fix: grep `mkForce` in modules/ + configurations/ before overriding; match with `lib.mkForce` or gate behind the same mkIf.

---

**msmtp `--passwordeval` bakes a path at build time**

Symptom: email alerts fail to auth after a rebuild, or the alert script references a stale secret path. Cause: modules/nixos/email-alerts/config.nix:56 uses `--passwordeval="cat '$SECRET' | tr -d '[:space:]'"` where the path is baked into the built script. Fix: guard with `config.age.secrets ? "name"` and ensure the manifest owner/mode makes the file readable by the alert user.

---

**launchd KeepAlive `Crashed = false` means "restart when NOT crashed" — the agenix restart loop**

Symptom: On nix-darwin, the `activate-agenix` launchd agent restarts every ~10 seconds after a successful run (`SuccessfulExit`), repeating forever. Cause: launchd `KeepAlive` semantics — `Crashed = false` means "restart when the job did NOT crash" (i.e. on successful exit), the opposite of the systemd intuition. The upstream agenix home-manager module sets a `KeepAlive` containing `Crashed = false` (plus `SuccessfulExit = false`), so every clean run is treated as a crash and relaunched. Fix: `modules/home/core/agenix.nix` (line ~27) overrides the agent's `KeepAlive` with `lib.mkForce { SuccessfulExit = false; }` — dropping `Crashed` entirely, keeping only "restart on failure". `mkForce` is required because the upstream module's `KeepAlive` is an attrset we must replace wholesale, not merge; a plain assignment would be merged with (and lose to) the upstream value. See upstream agenix#308; permanent fix tracked in agenix PR #352.

---

**Hyprland sddm branch force-disables greetd with `mkForce` — host/VM greetd assignments would conflict**

Symptom: Setting `my.desktop.hyprland.displayManager.greeter = "sddm"` while some other config (e.g. the desktop's VM-test `extraConfig`, or a future host) also sets `services.greetd.enable = true` produces a Nix evaluation error: `The option 'services.greetd.enable' has conflicting definition values` — or, if silently merged, leaves greetd and SDDM racing for the VT. Cause: inside the `greeter == "sddm"` branch, `modules/nixos/hyprland/display-manager/config.nix` (line ~35) needs greetd disabled, but a host or VM module sets `services.greetd.enable = true` at the same (default) priority — and the Nix module system errors on two plain definitions of equal priority rather than picking one. Fix: the sddm branch sets `services.greetd.enable = lib.mkForce false` so the display-manager module's choice always wins over any plain/mkDefault assignment elsewhere. `mkForce` is necessary because the conflicting assignment is made by a different module (host config) that we don't control; `mkDefault` would lose, and a plain `false` would conflict. Never "fix" this by removing the `mkForce` — instead gate host-level greetd assignments behind the same `greeter` condition if you need to coexist.

---

**Windows installer re-runs on every boot if `.done` is missing**

Symptom: Every NixOS boot triggers the `windows-installer` service, downloading a Windows ISO and attempting a reinstall even though Windows is already installed. Cause: The service only checks for `/var/lib/windows-installer/.done` — if that file is absent, it assumes Windows isn't installed. Fix: The service now includes a pre-flight idempotency check: it probes the Windows partition for an NTFS filesystem via `ntfs-3g.probe` and checks for `bootmgfw.efi` on the ESP. If either exists, it creates `.done` and exits immediately.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**Windows Setup overwrites GRUB as default EFI boot entry**

Symptom: After a successful Windows install, the machine boots directly into Windows instead of GRUB. Cause: Windows Setup always makes itself the first EFI boot entry. Fix: The `windows-post-install` service runs once after the first NixOS boot following Windows install. It checks if GRUB is the default entry and uses `efibootmgr --bootorder` to restore GRUB to the front. It also removes the stale "Windows 11 Setup" entry.

---

**DSC config is injected into Windows ISO but never applied**

Symptom: The `dsc-configuration.yaml` is placed in the ISO's OEM directory (`sources\$OEM$\$$\Setup\Scripts\`) but Windows never actually runs `dsc config set` during setup. Cause: The `autounattend.xml` had no `FirstLogonCommand` to execute the DSC bootstrap, and Windows 11 doesn't ship with DSC v3. Fix: The refactored `autounattend-xml` package now generates a bootstrap PowerShell script (`apply-dsc.ps1`) that installs PowerShell 7 + DSC v3 and applies the config. The `autounattend.xml` includes a `FirstLogonCommand` (order 5) to run this script.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**`autounattend.xml` heredoc in services.nix is fragile**

Symptom: Editing the inline XML in `services.nix` breaks string interpolation, and the XML duplicates the `packages/autounattend-xml` package. Cause: The installer service contained a 100+ line XML heredoc that was hard to maintain and had no build-time validation. Fix: The service now calls `pkgs.callPackage ../../../../packages/autounattend-xml` to build the XML at evaluation time. The generated XML is copied from the Nix store path during the install script.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**Answer file XML refactor — templates moved to packages/ventoy/answer-files/**

Symptom: Changes to Windows unattended answer XML aren't reflected after rebuild. Cause: The answer file XML was extracted from inline Nix strings to standalone `packages/ventoy/answer-files/{dev,minimal,domain,kiosk,dual-boot}.xml` templates with `@VAR@` placeholders. The `buildAnswer` function now uses `pkgs.substituteAll` instead of `pkgs.runCommand` with heredocs. Fix: Edit the `.xml` files directly. The `@VAR@` placeholders are substituted from the Nix `answerFileConfigs` and `answerFileSettings`. The product key (`VK7JG-NPHTM-C97JM-9MPGT-3V66T`) is still hardcoded in `answer-files.nix`.

---

**Nginx location collision between proxy services — `^~` prefix with longest-match wins for sequence-distinguishable paths**

Symptom: RisuAI SPA fails to load at `/risuai/`. Browser receives Open WebUI's HTML instead of RisuAI's JS/CSS/API responses. Cause: Two proxy upstreams (RisuaAI, Open WebUI) register `extraLocations` targeting the same root-absolute paths (`/assets/`, `/api/`). Open WebUI uses a regex `~ ^/(_app|static|api|ws|assets|auth|error|s/|watch)($|/)` which, per nginx precedence, beats plain prefix locations regardless of config order. Fix: Use `^~` modifier on prefix locations to make them immune to regex matches. For `/assets/`: only RisuAI uses it — add `^~` to RisuAI's `/assets/` location. For `/api/`: RisuAI uses bare `/api/*` (`/api/read`, `/api/write`, etc.) while Open WebUI uses `/api/v1/*` — these are sequence-distinguishable at the second segment. Add `^~ /api/v1/` to OWUI's extraLocations and `^~ /api/` to RisuAI's extraLocations; nginx's longest-prefix-win for `^~` routes `/api/v1/*` → OWUI and `/api/*` → RisuAI correctly. Only a true same-length collision (both services wanting identical path) would require sub_filter or path rewriting.
**Historical note:** This was fixed in the nginx-based proxy setup. The current proxy module uses **Caddy** (`modules/nixos/proxy/`), which uses first-match `handle`/`handle_path` semantics rather than nginx's regex-vs-prefix precedence. The `extraLocations` pattern was carried forward; Caddy avoids this class of bug naturally. The `^~` modifier is nginx-specific and not needed in the current architecture.

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

---

**Agenix secrets default to `root:root 0400` — home-manager/user-level consumers can't read them**

Symptom: `my.programs.squidProxyClient` (`proxy-browser` / `proxy-browser-persist`) launched a browser but pages failed to load through the Squid proxy. Cause: The client reads the password from `config.age.secrets."squid-htpasswd".path` (`/run/agenix/squid-htpasswd`), but the manifest entry had `owner: root, group: root, mode: 0400`. The shell alias's `$(<...)` substitution and the qutebrowser `config.py` both run as user `seanc`, got `Permission denied`, and produced an empty password — so the proxy URL was `http://seanc:@...:3128` and Squid returned 407. The server-side `squid-htpasswd-gen` service works because systemd oneshots run as root. Fix: Set `owner: "seanc", group: "users"` on `squid-htpasswd` in `modules/nixos/secrets/secrets-manifest.json` (root can still read it on the server). The manifest is eval-time SSOT: `nix eval .#nixosConfigurations.desktop.config.age.secrets."squid-htpasswd".owner` confirms the mapping. Must redeploy (`nix run .#activate`) to re-chown `/run/agenix/...`; the runtime `/etc/agenix/secrets-manifest.json` is NOT overwritten by rebuilds, so the change comes from the repo file at eval time. Check `discord-auth` / `mcp-better-email-password` (owner `seanc`) for the established pattern.

---

**Shell aliases that embed `$(<secret)` must NOT wrap the whole command in single quotes**

Symptom: After fixing secret ownership, `proxy-browser` still failed with `qutebrowser: Invalid URL ... scheme = "http", host = "seanc", path = "/run/agenix/squid-htpasswd)...@...` — the literal `$(</run/agenix/squid-htpasswd)` text was passed to qutebrowser unexpanded. Cause: `home.shellAliases."proxy-browser"` wrapped the qutebrowser `:set content.proxy ...` argument in single quotes: `':set content.proxy http://user:$(<file)@host:port'`. Single quotes make the `$(<...)` substitution literal, so the password never expands and the resulting URL is invalid. Fix: Use shell concatenation so the command substitution sits in a double-quoted segment: `':set content.proxy http://user:'"$(<file)"'@host:port'`. Nix-interpolate only the Nix values (`${cfg.proxyUsername}`, `${pwdFile}`, ...); leave `$(<...)` as literal shell. Verify the rendered alias with `nix eval .#nixosConfigurations.desktop.config.home-manager.users.seanc --apply 'c: c.home.shellAliases."proxy-browser"'`. See `modules/home/squid-proxy-client/config.nix`.

---

**Tailscale data plane wedged — BackendState "Running" but all TCP/ICMP time out**

Symptom: `ssh seanc@server` times out. From a healthy peer: `tailscale ping server` **pongs** (userspace OK), but `ping`, `nc server 22`, and all TCP to the server time out; server-side diagnostics look perfect (sshd listening on `0.0.0.0:22`, `tailscale0` UP with correct IP, low load, no firewall drops). The box self-recovers without any change. Cause: `tailscaled` owns `tailscale0` and silently reverts the interface MTU to its default (1280) on netmap updates (serve changes, `tailscale-manager` applies, reauth). The old `tailscale-mtu` unit was a boot-time one-shot (`RemainAfterExit=true`, no `PartOf`) so the configured `mtu = 1200` silently drifted back to 1280. On an MTU-constrained path this is an asymmetric blackhole: small control packets (`tailscale ping`, SYNs) get through, larger WireGuard datagrams get dropped → one-way data plane death (desktop saw `tx 11544 rx 92`). Confirm: `ip link show tailscale0` shows `mtu 1280` while `nix eval .#nixosConfigurations.server.config.my.services.tailscale.mtu` = `1200`. Fix: (1) the module now re-asserts the MTU on every `tailscaled` restart (`partOf`) AND on a `tailscale-mtu.timer` (default 5min), see `modules/nixos/tailscale/config.nix`; (2) the watchdog now probes the kernel data plane (interface UP, MTU match, self-path ping) and restarts `tailscaled` + emails when unhealthy (`autoRepair`, default true), see `modules/nixos/tailscale-watchdog/config.nix`. Immediate recovery: `ip link set dev tailscale0 mtu 1200` (root). Fastest diagnosis next time: from the desktop run `tailscale ping server`; if it pongs but `nc server 22` times out, the data plane is wedged — run `ssh` to the PiKVM console (`100.70.43.44`) and check `ip link show tailscale0 | head -1`.

---

**Server appears "wedged" but MTU is fine — actually OOM (nix flake check on the server)**

Symptom: Same signature as the MTU wedge — `tailscale ping server` pongs (userspace) but `nc server 22` and all TCP time out; from the PiKVM console `ip link show tailscale0` shows the correct `mtu 1200` and the `tailscale-mtu.timer` is firing every 5min cleanly. The real cause: a `nix` process (e.g. `nix flake check` or `nix run .#...` run on the server) ballooned to ~9GB RSS and got **OOM-killed** (server has 13Gi RAM, **no swap**), stalling the whole box — `uptime` load ~100, sshd/tailscaled can't respond in time, so TCP times out exactly like the data-plane wedge. Confirm: `uptime` shows load > 50 and `dmesg -T | grep -i oom` shows `Out of memory: Killed process ... (nix) total-vm:~9GB`. Recovery: the OOM kill itself resolves it (box recovers once the process is gone); `systemctl restart tailscaled` gives an immediate nudge. Prevention: **don't run `nix flake check` (or a full `nix run .#test`) on the server** — evaluating all flake outputs needs > 9GB. Run checks on the desktop instead, or add swap/zram to the server. Related bug (2026-08-01): the watchdog was silently dead — `HOSTNAME=$(hostname)` failed with `hostname: command not found` (coreutils provides `uname`, not `hostname`; the `writeShellApplication` PATH doesn't include it) → exit 127 → no auto-repair, no alerts. Fixed to `HOSTNAME=$(uname -n)`. Fastest diagnosis next time: check `uptime` (load) and `systemctl --failed` from the PiKVM before touching MTU.

---

**Tailscale data-plane wedge that passes every local watchdog probe — a remote peer never answers (2026-08-05)**

Symptom: `ssh seanc@server` times out, `tailscale ping server` pongs, and the desktop's `tailscale status --json` shows `lastHandshake` = zero epoch / `rxBytes: 0` for the server even though `txBytes` grows (this machine is sending handshakes that never complete). Server-side diagnostics via the PiKVM look perfect: `tailscale0` UP with the correct `mtu 1200`, `tailscale-mtu.timer` AND `tailscale-watchdog.timer` both active, load 0.04, sshd healthy on the LAN (`SSH-2.0-OpenSSH_10.3` banner, port 22 open). Crucially, a third machine on the **same LAN as the server** (the PiKVM at `192.168.12.122:41641`, 2ms direct) also times out on ALL TCP to the server over tailscale while the plain-LAN TCP to the server works — so this is NOT the MTU wedge (no constrained path involved) and NOT OOM (load is fine); it's tailscaled's kernel data plane wedged for everyone while its userspace (BackendState "Running", disco pings, WireGuard handshakes) keeps answering. The old watchdog probe missed it entirely: it only checks `tailscale0` exists/UP, MTU match, and a **self-ping** to the local IP — none of which exercise the remote forwarding path. Confirm: `ip link show tailscale0` (MTU correct), `systemctl is-active tailscale-mtu.timer tailscale-watchdog.timer` (both active), and from a peer on the same LAN `nc <server> 22` times out while `nc <server-LAN-ip> 22` succeeds. Fix: (1) watchdog gained a **remote-peer kernel data-plane probe** — when any peer reports `Online`, it pings candidates **through tailscale0** (explicit `canaryPeers`, or auto-selected most-recent Online non-iOS/Windows peer); if no candidate answers after two passes it restarts `tailscaled` + emails, see `modules/nixos/tailscale-watchdog/config.nix`. (2) New `my.services.tailscaleWatchdog.canaryPeers` option pins the probe to always-on hosts (desktop/server/PiKVM). (3) Watchdog now enabled on the **desktop** too, not just the server. Immediate recovery: `systemctl restart tailscaled` on the wedged host (via PiKVM LAN SSH: desktop → `ssh -A root@100.70.43.44` → `ssh root@192.168.12.122`). Note: `writeShellApplication` scripts run `set -o errexit` — any command-substitution probe that can return non-zero MUST be guarded with `|| true` (the `REMOTE_FAIL=$(checkRemotePeer || true)` pattern), or the watchdog aborts before it can restart anything.

---

**New untracked files aren't visible to pure flake eval (`nix build` / `nix eval .#...`)**

Symptom: You add `packages/keepa-mcp/default.nix`, but `nix build .#packages.x86_64-linux.keepa-mcp` fails with `does not provide attribute 'packages.x86_64-linux.keepa-mcp'` — even though `nix eval --impure --expr 'builtins.getFlake ...'` lists it. Cause: Pure flake evaluation only sees **git-tracked** files; the autowiring (nixos-unified) globs `packages/` at eval time, but an untracked file isn't in the git tree snapshot. Fix: `git add packages/keepa-mcp/default.nix` before building/eval'ing it (no commit needed — staging is enough). Same applies to any new file that's supposed to be auto-wired as a flake output.

---

**cunicopia-dev/ebay-mcp (PyPI `ebay-mcp` 0.1.0) crashes on startup — `AttributeError: 'Server' object has no attribute 'list_tools'`**

Symptom: Running `uvx ebay-mcp` exits immediately with `AttributeError: 'Server' object has no attribute 'list_tools'` at import. Cause: The package pins `mcp>=1.0.0`, but its code uses the pre-1.0 FastMCP-style API (`@app.list_tools()` decorator on a raw `mcp.server.Server`), which was removed in mcp 1.0. You can't pin `mcp<1.0` because the dependency constraint forbids it. Fix: Don't use this package. Use `secondhand-mcp` (npm) or the official `@ebay/npm-public-api-mcp` for eBay; both work and are actively maintained.

---

**home-manager `systemd.user.*` units now use INI-section format — old flat keys (`after`, `wantedBy`, `serviceConfig`) fail the type check**

Symptom: `nixos-rebuild switch` dies with `A definition for option 'home-manager.users.seanc.systemd.user.services.easyeffects.after' is not of type 'attribute set of (...)'. Definition values: [ "pipewire.service" "pipewire-pulse.service" ]`. Cause: The pinned home-manager reworked `systemd.user.services/timers/...` to the systemd INI format (sections `Unit` / `Service` / `Install`). `after`/`before`/`wants`/`partOf` now live under `Unit`, `wantedBy` under `Install.WantedBy`, and `serviceConfig.*` fields become bare keys in the `Service` section; the old options were removed, so a list assigned to `after` is reinterpreted as a bogus section and rejected. Fix: migrate definitions, e.g. `{ serviceConfig.Type = "simple"; after = [ "x.service" ]; wantedBy = [ "default.target" ]; }` becomes `{ Unit = { After = [ "x.service" ]; }; Install = { WantedBy = [ "default.target" ]; }; Service = { Type = "simple"; }; }`. Notes: there is no `script`/`path`/`environment` convenience anymore — put shell in `Service.ExecStart` (wrap with `pkgs.writeShellScript` if needed) and set `Service.Environment = [ "PATH=..." ]`; `ExecStart` and `Environment` are the only typed `Service` fields (rest are freeform). See `modules/nixos/audio/config.nix` (fixed 2026-08-02); files still on the old format: `modules/nixos/hyprland/{idle,pyprland,bar,wallpapers}/config.nix`, `modules/nixos/gitreposync/{services,tests}.nix`.

---

**Cloud secrets (.age files) can't be decrypted after hosts were rekeyed**

Symptom: `nix run .#gcp -- plan` fails with provider auth errors, or `age -d -i <hostkey> modules/nixos/secrets/aws-cloud.age` reports `no identity matched any of the recipients`. Cause: the encrypted `.age` blobs were encrypted to host keys that have since been rotated (`/etc/ssh/ssh_host_ed25519_key` no longer matches any recipient in `/etc/agenix/secrets.nix`). The files are structurally valid but useless. Fix: regenerate via agenix-manager (`nix develop .#secrets && agenix-manager edit aws-cloud`) so they re-encrypt to the current keys. Guard all credential consumption in `modules/flake-parts/cloud.nix` with `[ -r /run/agenix/<name> ]` checks so evaluation never breaks on machines/CI without the secret.

---

**Terranix configs must live outside `modules/nixos/` (namespace violation)**

Symptom: a terranix module (options like `terraform.required_providers`, `resource.*`, `variable.*`) placed under `modules/nixos/<name>/default.nix` is autowired as `nixosModules.<name>`. It only evaluates because no host imports it — the moment `common.nix` or any host globs it, every host eval fails with `attribute 'terraform' missing` (terranix options aren't NixOS options). Fix: keep terranix modules under `cloud/` (see `cloud/README.md`); the flake-parts layer (`modules/flake-parts/cloud.nix`) wires them via `terranix.terranixConfigurations.*`.

---

**Terranix `${}` escaping is easy to get wrong**

Symptom: Terraform references render literally (e.g. the generated JSON contains `\${var.region}` or the wrong `$var.region`), or provider evaluation throws on unescaped Nix interpolation. Fix: use `lib.tf.ref "var.region"` / `lib.tf.file` in terranix modules instead of hand-rolling `\${...}`. Inside Nix string interpolation wrapping a reference (e.g. `"seanc:${lib.tf.ref "var.ssh_pub_key"}"`) the result is the literal `seanc:${var.ssh_pub_key}` — correct Terraform. Verify with `nix run .#tf-show-config | jq .`.

---

**Computed Terraform values can't feed Nix evaluation**

Symptom: interpolating an instance IP / resource attribute (known only after `apply`) into a NixOS config (e.g. via `terraform-nixos` deploy modules) renders an empty drvPath or `<computed>`. Cause: Nix evaluates at build time, Terraform resources resolve at plan/apply time. Fix: don't feed computed values into Nix. Use Terraform **outputs** + stage-2 tools (`nixos-anywhere`, `colmena`, or `nixos-rebuild --target-host`); pass only known-at-plan-time values (AMI ids, image families, key names) as variables.

---

**`agenix-manager new` secrets disappear after `nix run .#activate`**

Symptom: A secret created via `agenix-manager new --name foo --scope main` shows up in `agenix-manager status` immediately, but disappears after the next `nix run .#activate` (or `nixos-rebuild switch`). The `.age` file still exists but the entry is gone from the manifest.  
Cause: The upstream agenix-manager module's activation script (`agenixManagerSecretsNix`) writes all 4 files to `/etc/agenix/` on every rebuild — including `secrets-manifest.json`. The CLI's `new` command saves the updated manifest to `/etc/agenix/secrets-manifest.json`, but the activation script overwrites it with the repo-tracked version (which doesn't have the new secret yet). Additionally, `common.nix` had a redundant `agenixManagerSecretsManifest` activation script that overwrote the same file again.  
Fix: `modules/nixos/common.nix` now (1) overrides `agenixManagerSecretsNix` via `lib.mkForce` to skip writing `secrets-manifest.json` (only writes `secrets.nix`, `agenix-manager-cache.json`, `keys-snapshot.json`), (2) removes the redundant `agenixManagerSecretsManifest` script, and (3) replaces it with `agenixManagerSecretsManifestBootstrap` which only creates `/etc/agenix/secrets-manifest.json` on first boot. This preserves CLI-local manifest changes across rebuilds. To force re-sync from the repo: `sudo rm /etc/agenix/secrets-manifest.json && nix run .#activate`. The Nix evaluation always reads the repo file directly (`cfg.manifestPath`), so secret decryption is unaffected.

---

**Keep `disko.devices.disk.main` out of disk-config.nix in dualBoot mode**

Symptom: Running `just deploy-desktop` rewrites the GPT, destroying Windows partitions or creating a second disko layout on another disk. Boot fails with `VFS: Can't find ext4 filesystem` on wrong device.  
Cause: A host-level `disko.devices.disk.main` in `configurations/nixos/desktop/disk-config.nix` collides with the dualBoot module's layout selection. The dualBoot module at `modules/nixos/disko/config.nix` picks the layout via a Nix if-else (lines 5-6, `isFresh` vs `isExisting`) and force-sets `fileSystems` via `mkIf isExisting (mkForce …)` at lines 111-120; a separately-defined `disko.devices.disk.main` makes nixos-anywhere run `disko --mode create,format,mount`, rewriting the GPT.  
Fix: Keep `disko.devices.disk.main` out of `disk-config.nix`; the dualBoot module's if-else owns the layout. `disk-config.nix` now only uses `disko.devices.nodev` + `disko.devices._scripts` (explicitly no `disko.devices.disk`). Deploy with `just deploy-desktop` (`--disko-mode disko` auto-detected). The NixOS partition must be created manually once via `sgdisk` + `mkfs.ext4`; the Windows ESP is referenced by filesystem label (`/dev/disk/by-label/EFI`).

---

**steamcmd dedicated servers: run through `steam-run`, never harden with NoNewPrivileges**

Symptom: `game-server-<name>.service` fails to exec or the server binary crashes with missing 32-bit/glibc libs; or bwrap errors appear when the unit has strict systemd sandboxing. Cause: nixpkgs `pkgs.steamcmd` wraps the installer in `steam-run`'s FHS environment automatically, but the **game server binary itself** must also be executed via `steam-run` (that's why `my.services.game-servers` sets `ExecStart = steam-run ./<startCommand>`). steam-run is bwrap-based, so `NoNewPrivileges`, `PrivateMounts`, `ProtectSystem=strict` with no `ReadWritePaths`, and aggressive `SystemCallFilter`/`RestrictAddressFamilies` sets break it (same family as the jan AppImage gotcha). Fix: invoke every server through `steam-run`, keep hardening to `PrivateTmp` + `ProtectSystem=strict` + `ReadWritePaths=<stateDir>` + `ProtectHome=true`, and never set `NoNewPrivileges`. See `modules/nixos/game-servers/services.nix`. Related gotchas: `pkgs.steamcmd` fetches its installer from **web.archive.org** (Valve's CDN `steamcdn-a.akamaihd.net` is dead) so hash churn breaks rebuilds; steamcmd **refuses to run as root** (always use a dedicated service user); Unity-based servers (Valheim/Palworld/7DTD) need `steamworks-sdk-redist` in the FHS target pkgs.

---

**LinuxGSM is not packaged in nixpkgs (and never will be) — use steamcmd**

Symptom: Trying to add LinuxGSM to this flake fails — there is no `linuxgsm` package, and nixpkgs maintainers deliberately closed the packaging request (NixOS/nixpkgs#137459). Cause: LinuxGSM is an imperative, self-updating installer that shells out to apt/yum/dnf for dependencies and assumes a mutable `~/serverfiles/` layout — an anti-pattern on NixOS. Fix: Use `pkgs.steamcmd` + systemd instead (the `my.services.game-servers` module does exactly this). If a specific game's LinuxGSM script is truly required, the supported route is a declarative Ubuntu/Debian container, not a NixOS module.

---

**`nix flake check --no-build` fails with `path '...-secrets' is not valid` in a fresh CI store**

Symptom: Smart CI `flake-check` job fails with `error: path '/nix/store/<hash>-secrets' is not valid` while agenix-manager's `builtins.pathExists` reads the secrets manifest. The host `eval-*` jobs pass. Cause: `agenixManager.secretsPath = ./secrets` creates a *filtered* store copy named `<hash>-secrets` that is only realized lazily when its string context is forced. Under `--no-build` in a fresh store (no prior builds), that path doesn't exist yet, so `pathExists` on `${secretsPath}/secrets-manifest.json` aborts evaluation. Paths inside the flake's own source tree (`flake.inputs.self`, i.e. `<hash>-source`) are always realized during evaluation, so they never hit this. Fix: set `agenixManager.secretsPath = flake.inputs.self + /modules/nixos/secrets` instead of `./secrets` in `modules/nixos/common.nix`. This is the same `flake.inputs.self` pattern `nebula` already uses for its key files. Locally this issue is masked because the `-secrets` path already exists from prior builds. Bonus: the CLI's `_resolve_store_path` maps the `-source` tree path back to `$PWD/modules/nixos/secrets` correctly, so mutating operations (`new`, `remove`, `import`) now work when run from the flake checkout — the old `-secrets` path was too short for the resolver to handle.

Note: the same class of failure hits *any* source path realized only at eval time, not just secrets — e.g. `maccel`'s `cargoLock.lockFile`/`src` in `modules/nixos/mouse/config.nix` (a cargo git dependency fetched by `import-cargo-lock.nix`), surfacing as `path '...-source' is not valid`. Because this can't be pre-realized from inside the flake, the smart-ci `flake-check` job evaluates all flake outputs via `nix eval` (which realizes source paths) instead of `nix flake check --no-build`.

---

**`update-flake` workflow fails with git exit 128 in the `Create Pull Request` step**

Symptom: The weekly `Update Flake Inputs` workflow fails at the `Create Pull Request` step with `The process '/usr/bin/git' failed with exit code 128`. Cause: `peter-evans/create-pull-request` pushes to the `update-flake-inputs` branch, but if a previous PR was closed without merging, the remote branch is far behind master (e.g. 277 commits behind) while the workflow's local branch is based on current master — the push is a non-fast-forward and git rejects it with exit 128. Fix: add `force: true` to the `create-pull-request` step in `.github/workflows/update-flake.yml`. The branch is bot-managed, so force-pushing resets it to current master + flake.lock update every run. See `peter-evans/create-pull-request` docs.

---

**`ollama-pull-models.service` fails with `connect: no route to host` and fails the whole `nix run`**

Symptom: Running `nix run` (nixos-rebuild switch) returns non-zero exit status 4 because `ollama-pull-models.service` failed during model pull. Journal shows `Error: pull model manifest: Get "https://hf.co/...": dial tcp <IP>:443: connect: no route to host`. Cause: the pull service was a `Type=oneshot` with no retry — any transient network blip (e.g. IPv4 egress dead while IPv6 works, gateway ARP `INCOMPLETE`) failed the pull once, and `switch-to-configuration` reported the failed unit, failing the whole rebuild. Fix: `modules/nixos/ollama/services.nix` now wraps each `ollama pull` in a retry loop (`cfg.pull.retries`, default 5) with linear backoff (`cfg.pull.retryDelaySec`, default 10) and defaults `cfg.pull.restartOnFailure = true` which sets `Restart=on-failure`, `RestartSec=30s`, `StartLimitIntervalSec=0` on the service so a failed pull auto-retries indefinitely. See `modules/nixos/ollama/options.nix`.

---

**Tailscale at tunnel MTU 1200 disables IPv6 on tailscale0 (Linux requires ≥1280)**

Symptom: `tailscale status` health check reports `2 add route failures; first was: no such device` / `adding address fd7a:115c:a1e0::…/128 from tunnel interface: invalid argument`. Cause: Linux cannot assign an IPv6 address to an interface with MTU < 1280 (RFC 8200 minimum). With `my.services.tailscale.mtu = 1200`, tailscaled fails to add the Tailscale ULA IPv6 address — the tailnet IPv6 (fd7a:115c:a1e0::/48) is unusable from that host. This is expected and harmless for IPv4-only operation; IPv6-over-tailscale is simply unavailable. If IPv6 on the tailnet is required, raise the tunnel MTU to 1280+ and rely on MSS clamping (see `mss-clamp`) instead of lowering the interface MTU. See `modules/nixos/mss-clamp/`.

---

**New systemd timers show `NEXT: n/a` after a `nixos-rebuild switch` until `daemon-reload`**

Symptom: After deploying a new `systemd.timers.*` unit (e.g. `mss-clamp.timer`), `systemctl list-timers` shows the timer active but with `NEXT: -` and `Trigger: n/a` — it fires once at activation (OnBootSec catch-up) then never reschedules, even though `OnUnitActiveSec` is set and identical-pattern timers (e.g. `tailscale-mtu.timer`) schedule fine. Cause: the timer unit is loaded during the switch's systemd transition and the monotonic `OnUnitActiveSec` elapse isn't computed until the daemon re-reads the unit. Fix: `systemctl daemon-reload && systemctl restart <timer>.timer` once after the switch (self-corrects on the next reboot). See `modules/nixos/mss-clamp/config.nix`.

---

**`nixpkgs-fmt` mangles `.json` files — never run `nix fmt` on them**

Symptom: `nix fmt --check` reports a `.json` file "would have been reformatted". Running nixpkgs-fmt on `modules/nixos/secrets/secrets-manifest.json` produces garbage (it parses JSON as Nix and strips all structure). Cause: `nixpkgs-fmt` is a Nix formatter, not a JSON formatter, but `nix fmt` passes every file to it. Fix: never run `nix fmt` on `.json` files; validate them with `jq empty <file>` instead. This is pre-existing repo behavior, not a regression from any single change.

---

**`systemd.services.<name>.script` rejects a `pkgs.writeShellScript` derivation — use `toString`**

Symptom: `error: A definition for option 'systemd.services.<name>.script' is not of type 'strings concatenated with "\n"'` with the definition value shown as `<derivation mss-clamp>`. Cause: the `script` option's type is `str`, which does not auto-coerce a *derivation* to a store path (only plain `path`/`coercedTo` types do). Fix: assign `script = toString clampScript;` where `clampScript = pkgs.writeShellScript ...` — string interpolation of the derivation yields the store path. See `modules/nixos/mss-clamp/config.nix`.

---

**`services.ttyd.user` is a plain `str` (default `"root"`), not nullable**

Symptom: `error: A definition for option 'services.ttyd.user' is not of type 'string'` when passing `null` through a wrapper option. Cause: unlike many service modules, upstream ttyd's `user` is `types.str` with default `"root"` (needed because the `login` entrypoint must run as root) — there is no "unset" value. Fix: declare `user` as `nullOr str` in the wrapper and only set it when non-null via `lib.optionalAttrs (cfg.user != null) { user = cfg.user; }`. See `modules/nixos/ttyd/config.nix`. (Also note: `services.ttyd.writeable` must be explicitly set to `true`/`false` — the upstream module fails evaluation otherwise.)

---

**Tor onion-service key persists in `/var/lib/tor/onion/<name>/` — stable across rebuilds without agenix**

Symptom/context: Fear that a Tor onion SSH address changes on every rebuild. Cause: the NixOS tor module's `services.tor.relay.onionServices.<name>.secretKey` defaults to `null`, in which case Tor reuses any preexisting key in `path` (default `/var/lib/tor/onion/<name>`) or generates one. Because that directory lives on persistent disk, the onion address stays stable across reboots and rebuilds. Fix: no action needed on persistent hosts; point `secretKey` at an agenix-managed key only if the address must survive a full storage wipe. Onion services render regardless of `services.tor.relay.enable` — no relay is needed. See `modules/nixos/tor-ssh/`.

---

**NCCL (cuda-nccl) builds from source for hours — dep chain: nvshmem → openmpi → ucc → nccl**

Symptom: Running `nix run` on a host with `my.profiles.ai.enable` + `my.profiles.gpu.nvidia-headless` triggers NCCL to compile from source, taking hours. The build list shows `cuda12.9-nccl-2.28.7-1`, `ucc`, `openmpi` all being compiled. None of the configured substituters have these pre-built. Cause: The dependency chain is `python3-nvidia-nvshmem-cu13` (a pip wheel) → `pkgs.openmpi` (added as extra dependency by the stable-diffusion-webui-nix requirements overlay) → `ucc` (Unified Communication Collection) → `cuda12.9-nccl` (raw NCCL library, compiled from C++ source). This chain exists even though the Python-level `nvidia-nccl-cu13` wheel is already built and provides `libnccl.so.2`. Fix: Added an overlay in `modules/nixos/graphics/config.nix` that removes `ucc` from `openmpi`'s buildInputs via `overrideAttrs` + `builtins.filter`. OpenMPI auto-detects UCC at configure time — without it in build inputs, it simply disables UCC support. The Python `nvidia-nccl-cu13` wheel still provides NCCL to PyTorch/Bitsandbytes at the Python level. Also fixed the `cache.nixos-cuda.org` public key in `modules/flake-parts/caches.nix` which was mismatched (configured `cache.nixos-cuda.org-1:dykfIg...` vs actual `cache.nixos-cuda.org:74DUi4Ye...`).

---

**Zerotier now always-on (multi-user.target), independent of Tailscale**

Zerotier starts unconditionally at boot via `wantedBy = [ "multi-user.target" ]`, fully independent of Tailscale. No `After=`/`Requires=`/`Wants=` between the two services in either direction. The `tailscale-watchdog` no longer starts or stops zerotier — it only alerts on tailscale health. `openFirewall` defaults to `true` (UDP 9993 exposed). This is an intentional recovery-path tradeoff: second always-on VPN surface in exchange for reliable fallback access. Note: `serviceConfig.Restart = lib.mkForce "on-failure"` is still applied at `modules/nixos/zerotier/config.nix:24` — only the `wantedBy` mkForce was removed; keep the Restart mkForce (the upstream default would otherwise win).

---

**Generations built from an uncommitted (dirty) working tree are hard to diagnose retroactively**

Symptom: After a bad generation breaks Tailscale + login, `nix store diff-closures` returns empty (identical closures), and `git log` shows no commits in the range. The generation was built from uncommitted changes, so there's no commit to point at. The only clue is that the `-source` derivation's store path changed between generations. Fix: Commit before `nixos-rebuild switch`/`boot`, not just before `dry-activate` or `flake check`. A dirty tree makes post-hoc diagnosis depend entirely on `nix derivation show` and manual source-tree comparison — `git diff` at build time is the only record, and it's gone after the tree changes again.

---

**Express/FastAPI backends reject Caddy `X-Forwarded-For` — add `trustProxy` on the upstream registration**

Symptom: A service behind Caddy (via `my.services.proxy.upstreams.<name>`) logs `ValidationError: ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` (Express) or silently logs incorrect client IPs (FastAPI/uvicorn). The upstream module fixes the issue ad hoc in one service while sibling services remain broken.

Cause: Caddy's `reverse_proxy` always sets `X-Forwarded-For`, `X-Forwarded-Proto`, and `X-Forwarded-Host`. Express's `app.set('trust proxy', ...)` defaults to `false`, and uvicorn's `--forwarded-allow-ips` defaults to `127.0.0.1`. Neither trusts headers from Caddy (which is not on localhost from the container's perspective, or proxies from a non-loopback IP). Each framework has a different mechanism: Express checks a `TRUST_PROXY` env var (RisuAI's server.cjs), uvicorn reads `FORWARDED_ALLOW_IPS` (Open WebUI's start.sh passes it; Letta doesn't).

Fix: Set `trustProxy` on the upstream registration in the service's config.nix:
- `"express"` — tells readers the service needs `TRUST_PROXY=1` in its container/systemd env
- `"uvicorn"` — tells readers the service needs `FORWARDED_ALLOW_IPS=*` in its env
The corresponding env var must also be set in the service's `environment` attrs. The `trustProxy` field is the documented registry; the env var is what actually makes it work. Both must agree.

See `modules/nixos/proxy/options.nix` (upstream `trustProxy` option), `modules/nixos/risuai/config.nix` (Express example), `modules/nixos/letta/config.nix` (uvicorn example).

---

**`jan.service` fails with `status=134/ABORT` — Jan AppImage bwrap sandbox conflicts with systemd hardening**

Symptom: `jan.service` fails with `code=exited, status=134` on every start after `nixos-rebuild switch`. The main `Jan serve` process exits with SIGABRT. Cause: `pkgs.jan` is an AppImage wrapped via `appimageTools.wrapType2` — the `Jan` binary is a bwrap (bubblewrap) wrapper that creates a mount namespace sandbox. The systemd service used `DynamicUser = true` (state dir at `/var/lib/private/jan`, symlinked to `/var/lib/jan`) + `NoNewPrivileges = true` + `ProtectSystem = "strict"` + `ProtectHome = true`. bwrap's `--chdir "$(pwd)"` inside the new namespace couldn't traverse `/var/lib/private/` (mode 0700, root-owned), and even if it could, `Jan serve` requires a GTK display (it's a Tauri desktop app, not headless). Fix: Converted to a home-manager user service (`systemd.user.services.jan`) that runs in the user's graphical session. The service is `PartOf = [ "graphical-session.target" ]` and has no systemd sandboxing (bwrap already sandboxes itself). The `settings.json` is deployed via `home.file` to `~/.local/share/Jan/data/settings.json`. See `modules/nixos/jan/config.nix`.

---

**Waybar crashes silently (SIGABRT) on desktops without batteries — no auto-restart from `exec-once`**

Symptom: After Hyprland login, Waybar never appears. `pgrep -a waybar` returns nothing. `journalctl --user --no-pager` shows `.waybar-wrapped` dumping core with SIGABRT and stack traces from the `Battery` module. Cause: Two issues — (1) The Waybar disk module format string used `{used_gb}` which is not a valid format option in waybar v0.15.0, causing "disk: argument not found" errors. (2) The battery module in waybar v0.15.0 has a TOCTOU race (issue #5019) in `refreshBatteries()` where a HID++ battery device disconnecting mid-poll causes an uncaught `std::runtime_error` → `std::terminate` → SIGABRT. Since Waybar was launched via bare `exec-once = waybar` (no auto-restart), the process stays dead after crashing. Fix: (1) Changed disk format from `{used_gb}` to `{used}` (auto-scaled) and `path` to `paths` (array). (2) Migrated Waybar from `exec-once = waybar` to a systemd user service with `Restart=on-failure` (matching the pyprland/hypridle pattern) and updated `exec-once` to `systemctl --user start waybar`. The service is `partOf = [ "hyprland-session.target" ]` so it starts with the session and auto-restarts on crash. See `modules/nixos/hyprland/bar/config.nix` and `modules/nixos/hyprland/core/config.nix`.

---

**`nix flake check` reliably OOMs on ventoy-deploy — use a scoped check for fast iteration**

Symptom: Running `nix flake check --show-trace` exits with code 137 (SIGKILL from OOM) while evaluating `ventoy-deploy`. The output shows all prior checks (host configs, modules, packages) passing successfully, making it ambiguous whether the overall check passed or failed. Cause: `ventoy-deploy`'s derivation pulls in a heavy Windows ISO source tree via `github:Cairnstew/uup-dump-build-and-get-windows-iso`, which OOMs the nix evaluator during the Git cache fetch. Fix: For host config iteration (the common case), use the scoped check: `nix derivation show .#checks.x86_64-linux.build-<hostname>` (e.g. `build-desktop`). This validates the NixOS system derivation directly without touching ventoy or any other unrelated output. The full `nix flake check` is only needed when explicitly validating ventoy or the full flake surface. For VM-scope validation, `nix build .#packages.x86_64-linux.desktop-vm --dry-run` is a fine substitute that also avoids the OOM trigger.

---

**`pkgs.jan` exports `bin/Jan` (capital J) but service used `bin/jan` — `ExecStart=203/EXEC`**

Symptom: `jan.service` fails with `status=203/EXEC` on every start. The systemd unit enters auto-restart loop. Cause: The upstream nixpkgs `pkgs.jan` package (an AppImage wrapped via `appimageTools.wrapType2`) creates `/bin/Jan` (capital J, matching `meta.mainProgram`), but `modules/nixos/jan/config.nix` had `ExecStart = "${cfg.package}/bin/jan serve ..."` (lowercase j). systemd returns `203/EXEC` (exec format error / file not found) because no file exists at that path. Fix: Use `lib.getExe cfg.package` which resolves the correct binary name from `meta.mainProgram`. See `modules/nixos/jan/config.nix:39`.

---

**`suwayomi-sync-import` timer fires independently of server — curl exit code 7**

Symptom: `suwayomi-sync-import.service` fails periodically with `status=7/NOTRUNNING`. The journal shows "restoring backup..." followed immediately by the exit, with no GraphQL response. Cause: The `suwayomi-sync-import.timer` is `wantedBy = [ "timers.target" ]` and fires on its `OnCalendar` schedule independently. The service declares `after = [ "suwayomi-server.service" ]` and `wantedBy = [ "suwayomi-server.service" ]`, but these only apply when systemd co-starts both — the timer bypasses this dependency. When the server is restarting or Tailscale IP hasn't resolved yet, the restore curl fails with `CURLE_COULDNT_CONNECT` (exit code 7) and `set -euo pipefail` propagates it. Fix: Added a retry loop (up to 10 attempts, 3s apart) around the restore curl, guarded with `|| true`, so transient connection failures are retried. See `modules/nixos/suwayomi/sync-import.nix:67-83`.

---

**`git -c safe.directory="*"` is maximally permissive — scope to the literal path instead**

Symptom: A systemd oneshot service running as root that calls `git` on a user-owned repo fails with `fatal: detected dubious ownership in repository at '/tmp/foo'`. Fix: Use `git -c safe.directory="$REPO"` where `$REPO` is the literal path to the repo (already set as a script variable from the Nix config option). Avoid `git -c safe.directory="*"` — while functionally equivalent when all git invocations are scoped to a single Nix-declared path, the wildcard would suppress the ownership check for any path passed to git in the process, including paths that come from external input (e.g. a malicious backup filename). The literal-path form is both correct and self-documenting. See `modules/nixos/suwayomi/sync.nix:53,54,79`.

---

**`builtins.toJSON` in zerotier config.nix double-encodes local.conf → daemon fails to parse**

Symptom: `nix run` succeeds but zerotierone fails with `ERROR: unable to parse local.conf (root element is not a JSON object)`. The service restarts in a loop. Cause: `modules/nixos/zerotier/config.nix` line 11 was calling `builtins.toJSON cfg.localConf` and passing the resulting string to upstream `services.zerotierone.localConf`. The upstream module uses `pkgs.formats.json.generate` which already serializes the value to JSON — `builtins.toJSON` double-encodes the content (JSON string wrapping JSON). When `localConf` was `null` (not set), it passed `null` instead of `{ }`, which also triggered the upstream's symlink creation for a file containing just `null`. Fix: Pass the attrset directly: `localConf = if cfg.localConf != null then cfg.localConf else { };` — let the upstream module handle serialization.

> **RESOLVED** — 2026-08-03 — fix applied; config.nix:11 now passes the attrset directly

---

**`maccel-audit.service` fails with exit code 101 during `nixos-rebuild switch`**

Symptom: `nix run` (nixos-rebuild switch) succeeds but reports `maccel-audit.service` failed with `status=101/n/a`. The audit only prints `=== maccel boot audit ===` with no logger output. Subsequent boots work fine. Cause: The `maccel-logger` script uses `set -euo pipefail` and calls the `maccel` CLI (Rust binary). During a switch, the kernel module might be in a transitional state; the Rust CLI can panic (exit 101) when the sysfs interface is briefly unavailable. The `set -e` propagates the panic exit code to the service. Additionally, `EXPECTED_MODE` was set to the config value ("linear") which never matched the CLI output ("Linear Acceleration"), causing persistent WARN noise in every run. Fix: (1) Removed `set -e` from the logger script — it's a diagnostic tool and should never fail the service. (2) Changed `exit 1` to `exit 0` on missing-module checks. (3) Added `|| true` guard in the audit service script. (4) Added `modeDisplayMap` so `EXPECTED_MODE` matches the actual CLI output. See `modules/nixos/mouse/config.nix`.

---

**`tailscale-ssh-config` produces `Host null` / `Host` entries when DNSName is empty**

Symptom: `ssh server` fails with `no argument after keyword "hostname"`. The generated `/home/<user>/.ssh/config.d/tailscale` contains entries like `Host null` and `Host` with empty `HostName` lines. Cause: `tailscale status --json` can return Self/Peer entries with an empty `DNSName` string (e.g. when tailscale isn't fully authenticated). The jq filter only checked `.DNSName != null` but not `.DNSName != ""`, so empty-string DNSNames passed through and produced `HostName` with no argument. Fix: Added `.DNSName != ""` to the jq `select` filter. To recover: `sudo tee ~seanc/.ssh/config.d/tailscale > /dev/null <<< "$(head -3 ...)"` or regenerate via `sudo systemctl start tailscale-ssh-config` after deploying the fix. See `modules/nixos/tailscale/config.nix:153`.

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

---

**`rofi-wayland` package has been merged into `rofi`**

Symptom: `programs.rofi.package = pkgs.rofi-wayland;` or including `rofi-wayland` in `environment.systemPackages` caused `error: 'rofi-wayland' has been merged into 'rofi'`.  
Cause: Upstream nixpkgs merged `rofi-wayland` into the main `rofi` package — the separate package no longer exists.  
Fix: Use `pkgs.rofi` and `programs.rofi.package = pkgs.rofi;` instead.

---

**OpenCode global tool with `import { tool } from "@opencode-ai/plugin"` crashes server**

Symptom: Adding `my.programs.opencode.tools.print-test = ''import { tool } from "@opencode-ai/plugin" ...''` causes opencode to fail with `Unexpected server error` on any request. Without the tool, opencode works. Cause: Global tools at `~/.config/opencode/tools/` have no `package.json`/`node_modules/` (unlike project-level `.opencode/tools/` which do), so the `@opencode-ai/plugin` import can't be resolved and opencode's tool runtime crashes. The `tool()` function is a runtime identity function (returns `input` unchanged) — it only provides TypeScript types. `tool.schema` is just `zod`. Fix: Define tools as plain object exports without the import: `export default { description: "...", args: { key: { type: "string", description: "..." } }, async execute(args) { return "..."; } }`. The `{ type: "string", ... }` format is native JSON Schema that opencode's runtime consumes directly. The `tool()` wrapper adds no runtime behavior.

---

**`sudo act` fails on Docker 29+ — two separate errors with different fixes**

Symptom 1: Running `sudo act` fails with `Error response from daemon: mkdirat var/run/act: path escapes from parent`. Cause: Docker 27+ hardened `docker cp` to reject relative paths. `act` copies the workspace into the container via `docker cp` which triggers this check. Fix: Use `act --bind` to bind-mount the workspace instead of copying.
Symptom 2: Even with `--bind`, act fails with `Error response from daemon: mkdirat var/run: file exists` when extracting workflow metadata to `/var/run/act/`. Docker 29.x's `mkdirat` check fails because `/var/run -> /run` is a symlink in the container image, and `docker cp` cannot follow it. Fix: Use a custom image where `/var/run` is a real directory (not a symlink). Run `just act-image` to build `act-fixed:latest` from `modules/flake-parts/act-fixed.Dockerfile` which replaces the symlink with a real directory. Pass `-P ubuntu-latest=act-fixed:latest` to act. The `act-verify` wrapper, `.#act` app, and all `just act*` recipes include both `--bind` and `-P ubuntu-latest=act-fixed:latest` by default.

---

**ventoy-deploy env-var contract — modules/flake-parts/ventoy/deploy.nix → ventoy-deploy.sh**

Symptom: Calling `ventoy-deploy` outside the Nix wrapper (e.g. sourcing ventoy-deploy.sh directly in a test) fails with confusing errors about missing variables, or succeeds silently but does nothing. Cause: The script reads all its configuration from environment variables set by `modules/flake-parts/ventoy/deploy.nix`. `VENTOY_JSON` is mandatory (must point to a valid `ventoy.json` file path) — without it the script hits `cp '' destin`. `BUILD_INSTALLER_ISO`, `ISO_MAPPINGS`, `FILE_MAPPINGS`, `DEFAULT_DEVICE`, `MOUNT_POINT`, `SECURE_BOOT`, `GPT`, `LABEL` are required by the Nix wrapper but can be empty/zero. `GRUB_CFG`, `INSTALLER_ISO`, `RESERVE_SIZE_MB` are optional and only accessed when their enabling flags are set. Fix: Always run `ventoy-deploy` as the built binary (`nix build .#ventoy-deploy`). For testing, export the mandatory vars manually before sourcing the script. See `modules/flake-parts/ventoy/deploy.nix` lines 1-14 for the full parameter list.

---

**nixos-anywhere deploy fails — `nixos-anywhere` not found or wrong flake path**

Symptom: `nix run .#deploy-<host> -- <target>` errors with `nixos-anywhere: command not found` or `error: flake 'path:...' does not provide attribute 'nixosConfigurations.server'`. Cause: `--flake ".#$host"` resolves relative to CWD — if run outside the flake root, the config won't be found. Fix: Always run deploy from the flake root. Use `just deploy-run <host>` which ensures correct CWD.

---

**Desktop dual-boot: nixos-anywhere skips disko but target isn't partitioned yet**

Symptom: nixos-anywhere runs `install` phase but fails because `/mnt` filesystems don't exist. Cause: Desktop uses `useExisting` mode which has no `disko.devices` — nixos-anywhere skips the disko phase entirely. The NixOS partition must exist before deployment. Fix: Before deploying to the desktop, boot a NixOS live USB, check `lsblk`, create a partition in the free space with `mkfs.ext4 /dev/nvme0n1p5`, and update `nixosPartition` in `configurations/nixos/desktop/default.nix` if the device is different. Run `nix run .#deploy-desktop -- <IP>` which uses `--phases kexec,install,reboot`.

---

**Post-install: agenix secrets not decrypted on first boot**

Symptom: After nixos-anywhere install, the machine boots but agenix secrets (tailscale auth key, GitHub token, etc.) aren't decrypted — services that depend on them fail. Cause: agenix encrypts secrets with the host's SSH key (`/etc/ssh/ssh_host_ed25519_key.pub`). On first boot, this key is freshly generated by OpenSSH and doesn't match any key that secrets were encrypted with. Fix (two options):
- **Preferred:** The deploy wrapper auto-detects when host key pre-provisioning is needed (host has `disk-config.nix` sidecar). Before deploying, run `nix run .#prepare-keys-<host>` to generate the key pair, add the public key to `modules/nixos/common.nix` (`agenixManager.keys.systems`), then `agenix-manager rekey`. Then `just deploy-run <host> <ip>` will include `--extra-files` automatically.
- **Existing workaround (post-deploy):** Fetch the new host key, add it to `modules/nixos/common.nix` under `agenixManager.keys.systems`, run `agenix-manager rekey` to re-encrypt all secrets, then rebuild. This is only needed once per machine.

---

**`nix flake check` fails after adding disk-config.nix — disko module not imported**

Symptom: `nix flake check` errors with `The option 'disko.devices' does not exist` when evaluating a host that imports `disk-config.nix`. Cause: The disko NixOS module must be imported before any `disko.devices` option can be set. The host config must have `inputs.disko.nixosModules.default` in its imports (which happens via `nixosModules.common` → `modules/nixos/disko/default.nix`). If the host doesn't import `common.nix`, disko options won't exist. Fix: Always import `flake.inputs.self.nixosModules.common` in every NixOS host config that uses `disk-config.nix`.

---

**DSC config always null in netboot autounattend — Windows installs come unconfigured**

Symptom: Every PXE-installed Windows machine has no registry tweaks, WSL features, or telemetry reduction applied, even though the `autounattend.xml` bootstraps DSC. Cause: The autounattend builder parameter `dscConfigPath` was always passed as `null` from the netboot module, and the `apply-dsc.ps1` bootstrap script looked for a YAML file at `C:\Windows\Setup\Scripts\dsc-configuration.yaml` that was never injected. Fix: Refactored into three parts: (1) autounattend-xml package now takes `dscConfigYaml` (string) instead of `dscConfigPath` (path), and generates `apply-dsc.ps1` with the YAML embedded as a PowerShell here-string; (2) netboot/options.nix adds a `dscConfig` attrs option on both machine and profile submodules; (3) netboot/config.nix calls `flake.inputs.dscnix.lib.evalDscConfiguration` to render the YAML from the machine's `dscConfig`, passes it to the builder, and symlinks `apply-dsc.ps1` into the HTTP root alongside `autounattend.xml`. The `FirstLogonCommand` downloads the script via `iex (iwr ...).Content` from the PXE HTTP server. See `packages/autounattend-xml/default.nix` and `modules/nixos/netboot/config.nix`.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**natShare and netboot both enable dnsmasq on the same interface, silently merging configs**

Symptom: The desktop PXE client gets a DHCP lease but never receives iPXE binaries — it gets stuck at "DHCP lease acquired, then nothing". Cause: natShare enables dnsmasq with a plain `dhcp-range` for internet sharing, and netboot (in daemon mode) enables its own dnsmasq with `dhcp-range` + PXE boot options on the same interface. Nix's attrset merge silently combines both configs, but dnsmasq only uses one `dhcp-range` directive, usually the wrong one, and the PXE-specific `dhcp-boot`/`dhcp-match` options may be lost entirely. Fix: When netboot detects natShare is co-located on the same interface (`sameAsNatShare`), it skips its own dnsmasq and delegates PXE options to natShare via `my.services.natShare.extraDnsmasqSettings`. The natShare module merges these extra settings into its dnsmasq `settings` attrset via `//` merge. See `modules/nixos/netboot/config.nix` lines 297-308 and `modules/nixos/natShare/config.nix` lines 45-53 for the delegation plumbing.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**`netboot-serve` heredocs fail build with `writeShellApplication`**

Symptom: Building `netboot-serve` fails with `syntax error near unexpected token '}'` or shellcheck SC2034 warnings after editing the script. Cause: `writeShellApplication` runs `shellcheck --severity=error` and `bash -n` on the script. Heredoc delimiters (like `IPXE`) must be at column 0 in the generated script, but Nix indented strings (`''...''`) strip the common prefix, leaving them indented. Also, unused variables cause SC2034 which is treated as error. Fix: Use `{ echo '...'; echo '...'; } > file` blocks instead of heredocs. Delete or prefix unused variables with `_`. Test locally with `nix build .#netboot-serve`.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**`tailscale-manager` fails on first deploy because Terraform isn't initialized**

Symptom: `tailscale-manager.service` fails with `✗ Terraform is not initialized. Run 'tailscale-manager init' first.` on first deployment. Root cause: The upstream NixOS module only writes policy/auth-key files in `ExecStartPre` but never runs `tailscale-manager init` to set up the Terraform workspace (`.terraform/`). The `apply` command refuses to proceed if the workspace doesn't exist. Fix: The local `modules/nixos/tailscale/config.nix` adds `preStart = "${config.services.tailscale-manager.package}/bin/tailscale-manager init"` which injects an `ExecStartPre` entry that runs init before apply. This is merged with the upstream's existing `ExecStartPre` entries via NixOS's `unitOption` merge (lists are concatenated). On an already-broken system, also run `sudo tailscale-manager init` manually in `/var/lib/tailscale-manager/` to initialize the existing state dir.

---

**`tailscale-manager` structured policy serialization includes empty nested fields, breaking Tailscale API**

Symptom: `tailscale-manager.service` fails with `json: unknown field "appConnectors" (400)` after migrating to `services.tailscale-manager.policy` structured options. Cause: The upstream v0.3.2 `policyToJSON` uses shallow `lib.filterAttrs` that only cleans top-level keys. Empty submodule defaults like `autoApprovers = { appConnectors = []; exitNode = []; routes = {}; }` pass through, and Tailscale's API rejects `appConnectors` when it's not yet supported or recognized. Fix: Use the raw `services.tailscale-manager.acl.policy` string instead of structured `policy.*` options. The raw string passes through without serialization and avoids the nested-defaults issue. **Update (2026-08-03):** the module has since re-migrated to the structured `policy.*` options — `modules/nixos/tailscale/manager.nix:16-43` now builds the upstream `services.tailscale-manager.policy` attrset directly from `cfg.policy.*`, including `appConnectors` (manager.nix:35) and `autoApprovers` (manager.nix:36), merged with `cfg.policy.extraConfig`. The raw `acl.policy` string workaround was removed and is now historical.

> **RESOLVED** — 2026-08-03 — module re-migrated to structured `policy.*`; `modules/nixos/tailscale/manager.nix:16-43` passes `policy.appConnectors` (:35) / `policy.autoApprovers` (:36) directly; raw `acl.policy` workaround removed.

---

**`nix run` kills GNOME/Wayland session during activation**

Symptom: Running `nix run` (which does `nixos-rebuild switch`) kills the desktop session — GNOME Shell, pipewire, wireplumber all stop, screen goes black. The VM test (`nix run .#test run laptop`) passes fine. Cause: Home-manager's default `systemd.user.startServices` setting (`"start"`) does `systemctl --user daemon-reload` and restarts all changed user services, which includes the entire GNOME session. Fix: Set `systemd.user.startServices = "sd-switch"` in `modules/nixos/homeManager/config.nix`. The `sd-switch` method is smarter — it only restarts services whose units actually changed, avoiding the session kill.

---

**Windows autounattend.xml password is in plaintext over HTTP**

Symptom: The Windows admin password is visible to anyone on the PXE network. Cause: `autounattend.xml` requires a plaintext `<Password><PlainText>true</PlainText></Password>`. The file is served from `/srv/pxe/machines/<MAC>/autounattend.xml` over unencrypted HTTP during PXE boot. Fix: This is inherent to the Windows unattended install protocol. Mitigations: (1) Use an isolated PXE VLAN; (2) set a temporary password and change it after install; (3) use `password` as a plain Nix option (acceptable for lab) or `passwordFile` pointing to a file readable at eval time (agenix runtime paths like `/run/agenix/windows-password` won't work — they don't exist at eval time).

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**netboot module and natShare both want dnsmasq on the same interface**

Symptom: `nixos-rebuild switch` succeeds but dnsmasq fails to start, or PXE clients get wrong DHCP leases. Cause: Both `my.services.netboot` and `my.services.natShare` enable `services.dnsmasq` and set `interface` to their own LAN interface. If both target the same interface, dnsmasq starts once with whichever config wins the merge — often the wrong one. Fix: Use different ethernet interfaces for each service, or disable one. The tests.nix assertion catches this at build time when both are on the same interface.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**`ventoy-deploy` auto-detection misses already-mounted Ventoy partition or mounts to wrong path**

Symptom: `sudo ventoy-deploy` mounts the Ventoy data partition to `/mnt/ventoy` even though udisks2 already auto-mounted it at `/run/media/$USER/Ventoy`, causing conflicts or duplicate mounts. Cause: Old script always mounted partition 2 to the hardcoded `ventoy.mountPoint` without checking if it was already mounted elsewhere. Fix: Script now calls `findmnt` to detect existing mounts before attempting its own mount. It also uses `lsblk --json`-style label matching and `ventoy -l` CLI verification for more reliable device detection. See `modules/flake-parts/ventoy/`.

---

**`ventoy-deploy` auto-detect includes `lsblk` tree-drawing characters in device path**

Symptom: `sudo ventoy-deploy` prints "Auto-detected Ventoy USB: /dev/└─sdc" then fails with "Can't lookup blockdev". Cause: `lsblk` default output uses tree formatting (with `└─`/`├─` characters) which get included in the constructed device path. Fix: Replaced `lsblk` tree output with `lsblk -dno NAME,RM` (disk-level list mode) combined with per-disk label queries via `lsblk -nlo LABEL`, eliminating the tree-formatting problem entirely. Applied in `modules/flake-parts/ventoy/`.

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

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**Repacked ISO missing UEFI boot catalog (OVMF can't boot)**

Symptom: After the installer repacks the ISO with `genisoimage`, UEFI firmware (e.g. OVMF) can't boot it — it only shows the legacy BIOS El Torito entry. Cause: The `genisoimage` command only passed `-b boot/etfsboot.com` for BIOS boot, with no `-eltorito-alt-boot` for UEFI. The original source ISO also lacked the UEFI El Torito entry (only had BIOS). Fix: Added `-eltorito-alt-boot -e efi/microsoft/boot/efisys.bin -no-emul-boot` so the repacked ISO has both BIOS and UEFI boot records. Fixed in `modules/nixos/windows-installer/services.nix`.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.*

---

**Migrated from `uup-builder` to pre-built GitHub release ISOs**

Symptom: ISO built via `uup-builder` (downloading UUP files + converting via `convert.sh`) was producing corrupt/broken ISOs. Cause: The uup-dump API and conversion pipeline had reliability issues. Fix: Replaced `uup-builder` flake input with `windows-iso-src` (points to `github:Cairnstew/uup-dump-build-and-get-windows-iso`). Step 1 of the installer now downloads a pre-built ISO from a GitHub release (split zip parts via aria2 + 7z extraction) instead of building one from UUP files. Removed `windowsBuild`, `windowsBuildId`, `windowsLang`, `windowsEdition` options; added `windowsReleaseTag`, `windowsImageIndex`, `isoChecksum`. Steps 2-8 (inject autounattend, DSC, repack, EFI boot) unchanged. See `modules/nixos/windows-installer/services.nix`.

**[SUPERSEDED]** — *Superseded: the referenced module(s) were dropped (commits 4d999a4, 3323acf) in favor of the PXE boot flow; retained for history.* windows-iso-src still consumed by configurations/nixos/desktop/default.nix:493.

---

**`serviceConfig.path` is silently ignored by systemd**

Symptom: Systemd services using `serviceConfig.path = [ ... ]` log `Unknown key 'path' in section [Service], ignoring` and commands from those packages aren't found at runtime (exit code 127). Cause: `path` is a NixOS-specific service option, not a systemd `[Service]` directive — it must be a **top-level** key in the service definition, not nested inside `serviceConfig`. Fix: Move `path = [ ... ]` outside `serviceConfig`, making it a sibling of `script`, `serviceConfig`, etc. Also check `services.nix` in `modules/nixos/ollama/` which has the same pattern.

---

**Installer ISO copy to Ventoy USB silently corrupts 1.5GB squashfs**

Symptom: ISO boots via Ventoy but fails with `fsconfig() failed: unable to read id index table`. The file size on the USB matches the store, and the first 10MB are identical, but the last 10MB differ (MD5 mismatch). Cause: The deploy script's `cp` to exfat silently corrupted the tail of the 1.5GB file. The `deploy_isos()` function uses hash-based `.deploy-state` tracking to verify copies, but the installer ISO was deployed by a separate code path (`deploy_installer_iso()`) that used plain `cp` with no checksum verification. Fix: Added SHA-256 integrity verification after every installer ISO copy with automatic retry. The fix is in `modules/flake-parts/ventoy/deploy-script/ventoy-deploy.sh` — the `cp` is now followed by `sha256sum` comparison of source and destination. On mismatch it deletes and retries once; if still mismatched, it exits with error. Always verify manually with `sha256sum $STORE_ISO $USB_ISO` before booting the target machine.

---

## Format

Each entry: **symptom → cause → fix**. One paragraph max. Newest at the top.

---

## Adding New Entries

When you discover a new problem and its solution:

1. Add it to the **top** of this file (newest first)
2. Follow the format: **symptom → cause → fix**
3. Keep it to one paragraph
4. Include the specific error message or symptom pattern
5. Prefix with `**[SUPERSEDED]**` when the fix references modules that no longer exist in this tree — retain the entry as history.
6. Add a `> **RESOLVED** — <date> — <how it was resolved>` line directly beneath an entry when the fix has been verified applied — keep the original text intact, matching the `**[SUPERSEDED]**` marker style.

---

Last updated: 2026-08-12

