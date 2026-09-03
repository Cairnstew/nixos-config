{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.comfyui;

  # ComfyUI core package. Default: repo-local v0.29.2 (see ./comfy/) — the
  # `stable-diffusion-webui-nix` input's `main` still pins v0.25.1 which has NO
  # native Krea 2 support; v0.29.2 ships comfy/ldm/krea2 + CLIPLoader type
  # "krea2". Building it reuses the input's own requirements machinery with a
  # regenerated flexseal lock from the vendored source (see ./comfy/README).
  # Override via `my.services.comfyui.package` (null = the repo-local default).
  comfyUiPackage =
    if cfg.package != null then cfg.package
    else import ./comfy { inherit pkgs flake; };

  # Curated, pre-pinned node catalog (url + rev + sha256, fetchSubmodules=true
  # to match the prefetch). `presets` selects names from it; an explicit
  # `customNodes` entry with the same attr name overrides the catalog pin.
  catalog = import ./catalog.nix;

  presetNodes = lib.listToAttrs (map
    (name: {
      inherit name;
      value = {
        enable = true;
        url = catalog.${name}.url;
        rev = catalog.${name}.rev;
        sha256 = catalog.${name}.sha256;
        fetchSubmodules = true;
      };
    })
    cfg.presets);

  # customNodes wins per-name over presets.
  allCustomNodes = presetNodes // cfg.customNodes;

  enabledNodes = lib.filterAttrs (_: n: n.enable) allCustomNodes;

  # ComfyUI-Manager is NOT a legacy custom-nodes git clone anymore — ComfyUI
  # 0.25.x (main.py) checks `importlib.util.find_spec("comfyui_manager")` when
  # `--enable-manager` is set and SILENTLY disables the manager if the python
  # package is absent (warning + args.enable_manager = False). So the Manager
  # is built as a python package (comfyui_manager) and injected via PYTHONPATH.
  # Only the small missing deps are propagated (GitPython/PyGithub/etc load
  # lazily); transformers/huggingface-hub are already in the service env and
  # deliberately NOT re-added, so the env's versions are never shadowed.
  managerPkg =
    let
      src =
        if cfg.manager.rev != null && cfg.manager.sha256 != null
        then
          pkgs.fetchgit
            {
              url = cfg.manager.url;
              rev = cfg.manager.rev;
              sha256 = cfg.manager.sha256;
            }
        else builtins.fetchGit { url = cfg.manager.url; };
    in
    pkgs.python3.pkgs.buildPythonPackage {
      pname = "comfyui-manager";
      version = cfg.manager.version;
      inherit src;
      format = "pyproject";
      nativeBuildInputs = [ pkgs.python3.pkgs.setuptools pkgs.python3.pkgs.wheel ];
      propagatedBuildInputs = with pkgs.python3.pkgs; [
        gitpython
        pygithub
        toml
        chardet
        typing-extensions
      ];
      doCheck = false;
      pythonImportsCheck = [ ];
      # Skip the wheel's Requires-Dist verification (dontCheckRuntimeDeps):
      # transformers/hf-hub/typer/rich/uv are already in the service env (or
      # standalone tools) and are deliberately NOT propagated — re-adding them
      # would shadow the env's versions. The Manager imports lazily; boot needs
      # only aiohttp.
      dontCheckRuntimeDeps = true;
    };

  managerEnv =
    if cfg.enableManager
    then pkgs.python3.withPackages (ps: [ managerPkg ps.pip ])
    else null;

  # PYTHONPATH fragment pointing at the manager package + its propagated deps.
  managerPythonPath =
    if cfg.enableManager
    then "${managerEnv}/${pkgs.python3.sitePackages}"
    else "";

  # Writable site-packages for RUNTIME pip installs (custom-node requirements).
  # The Nix python envs are store/read-only, so the Manager's `pip install`
  # (driven by PIP_TARGET) writes here; the dir is prepended to PYTHONPATH so
  # installed packages are importable. Created by comfy-ui-prepare-dirs.
  managerPipTarget = "${cfg.dataDir}/python-site-packages";

  managerPipEnv =
    if cfg.enableManager
    then ''
      export PYTHONPATH="${managerPipTarget}:${managerPythonPath}:$PYTHONPATH"
      export PIP_TARGET="${managerPipTarget}"
      # pip env (site-packages target) skips the store so any runtime
      # installs go to the writable target and the security scan passes.
      export PIP_DISABLE_PIP_VERSION_CHECK=1
    ''
    else "";

  # civitai-comfy-nodes (official orchestration pack) needs python-socketio at
  # RUNTIME for the link/collaboration feature — link.py does `import socketio`
  # (guarded ImportError) and shows "Needs python-socketio in ComfyUI's own
  # Python: <python> -m pip install \"python-socketio[client]\"" when absent.
  # Declarative instead of a runtime pip install: build socketio (the [client]
  # extra = + websocket-client; engineio comes along as a dep) into the
  # injected PYTHONPATH, exactly like the manager package above.
  hasCivitaiPack = lib.elem "civitai-comfy-nodes" (cfg.presets ++ lib.attrNames (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
  civitaiEnv =
    if hasCivitaiPack
    then pkgs.python3.withPackages (ps: [ ps.python-socketio ps.websocket-client ])
    else null;
  civitaiPythonPath =
    if civitaiEnv != null
    then "${civitaiEnv}/${pkgs.python3.sitePackages}"
    else "";
  civitaiLinkEnv =
    if hasCivitaiPack
    then ''
      export PYTHONPATH="${civitaiPythonPath}:$PYTHONPATH"
    ''
    else "";

  # ComfyUI-GGUF needs the `gguf` python module at import time (__init__.py →
  # nodes.py → ops.py does `import gguf` unguarded); without it the pack fails
  # with "ModuleNotFoundError: No module named 'gguf'" and UNETLoaderGGUF never
  # registers. It's not part of ComfyUI's own requirements lock, so inject it
  # into PYTHONPATH exactly like the manager/socketio envs above.
  hasGgufPack = lib.elem "ComfyUI-GGUF" (cfg.presets ++ lib.attrNames (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
  ggufEnv =
    if hasGgufPack
    then pkgs.python3.withPackages (ps: [ ps.gguf ])
    else null;
  ggufPythonPath =
    if ggufEnv != null
    then "${ggufEnv}/${pkgs.python3.sitePackages}"
    else "";
  ggufLinkEnv =
    if hasGgufPack
    then ''
      export PYTHONPATH="${ggufPythonPath}:$PYTHONPATH"
    ''
    else "";

  # Fetch custom node git repos. Two modes:
  #   rev + hash  → pkgs.fetchgit: a locked, pure derivation fetch. No
  #                 eval-time network, reproducible — works with a plain
  #                 `nixos-rebuild switch` / `nix run .#activate` (no --impure).
  #   url (+ref)  → builtins.fetchGit at eval time: convenient (no hashes to
  #                 compute) but impure — needs network during eval and breaks
  #                 pure activation (use only with --impure).
  customNodeSrcs = lib.mapAttrs
    (name: node:
      if node.rev != null && node.sha256 != null then
        pkgs.fetchgit
          {
            url = node.url;
            rev = node.rev;
            sha256 = node.sha256;
            fetchSubmodules = node.fetchSubmodules;
          }
      else
        builtins.fetchGit ({
          url = node.url;
          submodules = node.fetchSubmodules;
          allRefs = true;
        } // lib.optionalAttrs (node.ref != null) { ref = node.ref; })
    )
    enabledNodes;

  # Build CLI arguments from structured options
  cliArgs = lib.concatStringsSep " " (lib.flatten [
    (lib.optional (cfg.listenHost != null) "--listen ${lib.escapeShellArg cfg.listenHost}")
    "--port ${toString cfg.port}"
    (lib.optional cfg.enableManager "--enable-manager")
    # ComfyUI ≥ 0.26 keeps a sqlite DB (assets system); the default path is
    # computed from the python __file__ (the read-only Nix store), so point it
    # at the writable data dir or ComfyUI logs "unable to open database file"
    # on every boot. Supported since 0.25.1, safe for the fallback package.
    "--database-url sqlite:///${cfg.dataDir}/user/comfyui.db"
    (lib.optional (cfg.extraModelPaths != [ ])
      "--extra-model-paths-config ${extraModelPathsYaml}")
    (lib.optional (cfg.gpu.cudaDevice != null) "--cuda-device ${cfg.gpu.cudaDevice}")
    (lib.optional cfg.gpu.forceFp16 "--force-fp16")
    (lib.optional (cfg.gpu.vram != null) "--${cfg.gpu.vram}vram")
    (lib.optional (cfg.gpu.attention != null)
      "--use-${cfg.gpu.attention}-cross-attention")
    (lib.optional (cfg.gpu.previewMethod != null)
      "--preview-method ${cfg.gpu.previewMethod}")
    cfg.extraArgs
  ]);

  # Generate extra_model_paths.yaml
  extraModelPathsYaml = pkgs.writeText "extra_model_paths.yaml"
    (lib.concatStringsSep "\n" (map
      (m:
        let
          sectionName = m.name;
          baseLine = lib.optionalString (m.basePath != null) "    base_path: ${m.basePath}\n";
          defaultLine = lib.optionalString m.isDefault "    is_default: true\n";
          pathLines = lib.concatStringsSep "" (lib.mapAttrsToList
            (folderType: paths:
              let
                pathList = if builtins.isList paths then paths else [ paths ];
                pathStr =
                  if builtins.length pathList == 1 then
                    "    ${folderType}: ${builtins.head pathList}\n"
                  else
                    "    ${folderType}:\n" +
                    lib.concatStringsSep "" (map (p: "      - ${p}\n") pathList);
              in
              pathStr
            )
            m.paths);
        in
        "${sectionName}:\n${baseLine}${defaultLine}${pathLines}"
      )
      cfg.extraModelPaths));

  # ── Declarative models ─────────────────────────────────────────────────────
  # Each enabled model entry resolves to a final spec: url/type may be implied
  # by the URN, and the fetch mode decides where the bytes land:
  #   store     = build-time fetchurl (pure, pinned)  + symlink into dataDir
  #   download  = resumable curl into <dataDir>/models/<type>/ at activation
  #               (real file on the data disk; sha256 verify optional).
  #
  # URN: urn:air:<family>:<type>:civitai:<modelId>@<versionId>[+<fileId>]
  urnFolder = {
    checkpoint = "checkpoints";
    lora = "loras";
    vae = "vae";
    clip = "clip";
    text_encoder = "text_encoders";
    textencoders = "text_encoders";
    diffusion_model = "diffusion_models";
    diffusionmodel = "diffusion_models";
    embedding = "embeddings";
    controlnet = "controlnet";
    upscale_model = "upscale_models";
    upscalemodel = "upscale_models";
    unet = "unet";
  };
  parseCivitaiUrn = urn:
    let
      parts = lib.splitString ":" urn;
      idPart = if builtins.length parts == 6 then builtins.elemAt parts 5 else "";
      verFile = lib.splitString "+" idPart;
      modVer = lib.splitString "@" (builtins.head verFile);
      versionId = if builtins.length modVer == 2 then builtins.elemAt modVer 1 else null;
      fileId = if builtins.length verFile == 2 then builtins.elemAt verFile 1 else null;
    in
    {
      schema = if builtins.length parts >= 2 then "${builtins.elemAt parts 0}:${builtins.elemAt parts 1}" else null;
      family = if builtins.length parts == 6 then builtins.elemAt parts 2 else null;
      typePart = if builtins.length parts == 6 then builtins.elemAt parts 3 else null;
      source = if builtins.length parts == 6 then builtins.elemAt parts 4 else null;
      modelId = if builtins.length modVer >= 1 then builtins.elemAt modVer 0 else null;
      inherit versionId fileId;
      url =
        if versionId != null
        then "https://civitai.red/api/download/models/${versionId}${lib.optionalString (fileId != null) "?fileId=${fileId}"}"
        else null;
    };

  # sha256 attrs are nix base32 (52 chars, alphabet 0-9a-z minus e,o,u,t);
  # shell sha256sum needs hex, so convert at eval time (builtins.convertHash
  # was removed from modern Nix — this is a small pure-Nix decoder).
  sha256ToHex = s:
    # nix base32 (52 chars × 5 bits = 260 bits) → hex. Nix encodes the hash
    # as a LITTLE-ENDIAN byte integer then writes it big-endian in base32,
    # so hash byte i = bits[i*8 .. i*8+7] of the digit stream (the top 4 bits
    # of the 260 are pad for sha256 and must be zero). Works purely on small
    # bit/char ops — no 256-bit integers in Nix.
    let
      alphabet = "0123456789abcdfghijklmnpqrsvwxyz";
      hexChars = "0123456789abcdef";
      alphaChars = lib.stringToCharacters alphabet;
      alphaIdx = lib.listToAttrs (lib.imap0 (i: c: { name = c; value = i; }) alphaChars);
      binOf = n: len:
        let
          inner = x: if x == 0 then "" else inner (builtins.div x 2) + (if builtins.bitAnd x 1 == 1 then "1" else "0");
          raw = inner n;
          padStr = lib.concatStringsSep "" (lib.replicate len "0");
        in
        builtins.substring 0 (len - builtins.stringLength raw) padStr + raw;
      bits = lib.concatStringsSep "" (map
        (c:
          let i = alphaIdx.${c} or (throw "sha256ToHex: invalid nix-base32 character '${c}'");
          in binOf i 5)
        (lib.stringToCharacters s));
      whole =
        if builtins.stringLength bits != 260
        then throw "sha256ToHex: expected 52 nix-base32 chars for sha256, got ${builtins.toString (builtins.stringLength s)}"
        else bits;
      bval = b: (if b == "1" then 1 else 0);
      byteHex = i:
        let
          # Nix's base32 is the hash as a LITTLE-ENDIAN integer; byte i is
          # value >> (i*8), i.e. bits at positions 259-i*8 (LSB) … 252-i*8
          # (MSB) of the 260-char big-endian digit stream.
          bitsOfByte = lib.concatStringsSep "" (map (b: builtins.substring (259 - i * 8 - b) 1 whole) [ 7 6 5 4 3 2 1 0 ]);
          hi = lib.foldl' (acc: b: acc * 2 + bval b) 0 (lib.stringToCharacters (builtins.substring 0 4 bitsOfByte));
          lo = lib.foldl' (acc: b: acc * 2 + bval b) 0 (lib.stringToCharacters (builtins.substring 4 4 bitsOfByte));
        in
        builtins.substring hi 1 hexChars + builtins.substring lo 1 hexChars;
    in
    lib.concatStringsSep "" (lib.genList byteHex 32);

  # Normalize: a plain string value is the URN shorthand.
  modelEntries = lib.mapAttrs
    (name: e:
      if builtins.isString e
      then { urn = e; enable = true; mode = null; type = null; url = null; sha256 = null; }
      else e)
    cfg.models;
  enabledModels = lib.filterAttrs (_: e: e.enable) modelEntries;

  resolvedModels = lib.mapAttrs
    (name: e:
      let
        urnInfo = if e.urn != null then parseCivitaiUrn e.urn else null;
        folder =
          if e.type != null then e.type
          else if urnInfo != null && urnInfo.typePart != null && lib.hasAttr urnInfo.typePart urnFolder then urnFolder.${urnInfo.typePart}
          else null;
        url = if e.url != null then e.url else urnInfo.url or null;
        mode = if e.mode != null then e.mode else (if e.urn != null then "download" else "store");
      in
      {
        inherit name url folder mode;
        urn = e.urn;
        sha256 = e.sha256;
        sha256Hex = if e.sha256 != null then sha256ToHex e.sha256 else null;
        urnInfo = urnInfo;
      }
    )
    enabledModels;

  storeModels = lib.filterAttrs (_: m: m.mode == "store") resolvedModels;
  downloadModels = lib.filterAttrs (_: m: m.mode == "download") resolvedModels;

  # store mode: pure fixed-output fetch, symlinked into models/<type>/.
  modelSrcs = lib.mapAttrs
    (name: m: pkgs.fetchurl {
      inherit (m) url sha256;
      name = name; # keep the checkpoint/file name visible in the loader
      # Civitai's Cloudflare R2 .red/.com delivery drops mid-stream on large
      # files; Nix's builtin fetcher gives up after a couple of internal
      # attempts. curl-level retries make the long single download succeed
      # (the endpoint usually sustains ~50 MB/s once started).
      curlOptsList = [ "--retry" "20" "--retry-delay" "2" "--retry-all-errors" ];
    })
    storeModels;

  storeModelLinks = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: src:
      let
        srcPath = builtins.toString src;
        srcArg = lib.escapeShellArg srcPath;
        target = "${cfg.dataDir}/models/${storeModels.${name}.folder}/${lib.escapeShellArg name}";
      in
      ''
        target="${target}"
        if [ ! -e "$target" ]; then
          ln -sfn ${srcArg} "$target"
          echo "models: linked ${storeModels.${name}.folder}/${name}"
        elif [ -L "$target" ] && [ "$(readlink "$target")" != "${srcPath}" ]; then
          ln -sfn ${srcArg} "$target"
          echo "models: refreshed ${storeModels.${name}.folder}/${name}"
        fi
      '')
    modelSrcs);

  # download mode: resumable curl into dataDir/models/<type>/ at activation —
  # a REAL file on the data disk (no store bloat for GB-scale models). Hash
  # marker (.<name>.sha256 next to the file) short-circuits once verified.
  # Some civitai files are creator-gated ("requires you to be logged in"):
  # when `civitaiApiKeyPath` is set we send the key — read from the agenix
  # path at runtime by the root oneshot (no secret in store/script). curl -L
  # does NOT forward the Authorization header to a different redirect host,
  # so the key only ever reaches civitai(.com|.red), never the CDN.
  civitaiAuthHeader = lib.optionalString (cfg.civitaiApiKeyPath != null)
    "-H \"Authorization: Bearer $(cat ${lib.escapeShellArg (toString cfg.civitaiApiKeyPath)})\"";
  downloadModelScript = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: m:
      let
        # `workflows` is special: it lands in user/default/workflows/, where
        # ComfyUI actually loads workflow JSONs from, not under models/.
        base =
          if m.folder == "workflows"
          then "${cfg.dataDir}/user/default/workflows"
          else "${cfg.dataDir}/models/${m.folder}";
        target = "${base}/${name}";
        argTarget = lib.escapeShellArg target;
        marker = "${target}.sha256";
        argMarker = lib.escapeShellArg marker;
      in
      ''
        target="${argTarget}"
        marker="${argMarker}"
        # download mode keeps the REAL bytes on the data disk: drop a stale
        # store-mode symlink so ComfyUI reads the file, not the store.
        if [ -L "$target" ]; then
          rm -f "$target"
          echo "models: replaced store symlink with real file ${m.folder}/${name}"
        fi
        verify=0
        if [ -f "$target" ]; then
          ${if m.sha256 != null then ''
            # marker (fast) first; inline hash self-heals a marker-less file.
            if [ -f "$marker" ] && ${pkgs.coreutils}/bin/sha256sum -c "$marker" >/dev/null 2>&1; then
              verify=1
            elif echo "${m.sha256Hex}  $target" | ${pkgs.coreutils}/bin/sha256sum -c - >/dev/null 2>&1; then
              printf '%s  %s\n' "${m.sha256Hex}" "$target" > "$marker" 2>/dev/null || true
              verify=1
            fi
          '' else ''
            if [ -f "$marker" ] && [ "$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null)" = "$(${pkgs.coreutils}/bin/stat -c%s "$target" 2>/dev/null)" ]; then
              verify=1
            fi
          ''}
        fi
        if [ "$verify" != 1 ]; then
          echo "models: downloading ${m.folder}/${name}"
          tmp="$target.incomplete"
          rm -f "$tmp"
          ${pkgs.curl}/bin/curl -fsSL ${civitaiAuthHeader} --retry 1000 --retry-all-errors --retry-delay 2 --retry-connrefused -C - -o "$tmp" "${m.url}" \
            || ${pkgs.curl}/bin/curl -fsSL ${civitaiAuthHeader} --retry 1000 --retry-all-errors --retry-delay 2 -o "$tmp" "${m.url}"
          ${pkgs.coreutils}/bin/mv -f "$tmp" "$target"
          ${if m.sha256 != null then ''
            if ! echo "${m.sha256Hex}  $target" | ${pkgs.coreutils}/bin/sha256sum -c - >/dev/null 2>&1; then
              echo "models: sha256 mismatch for ${m.folder}/${name}" >&2
              rm -f "$target"
              exit 1
            fi
            printf '%s  %s\n' "${m.sha256Hex}" "$target" > "$marker"
          '' else ''
            ${pkgs.coreutils}/bin/stat -c%s "$target" > "$marker"
          ''}
          echo "models: downloaded ${m.folder}/${name}"
        fi
        if [ ! -f "$target" ]; then
          echo "models: FAILED to obtain ${m.folder}/${name} (401 auth-gated? set my.services.comfyui.civitaiApiKeyPath) — aborting" >&2
          exit 1
        fi
        # Always: make the data-disk file readable by the comfy-ui service
        # user (the oneshot runs as root; download and pre-existing files
        # alike must be owned by comfy-ui).
        ${pkgs.coreutils}/bin/chown comfy-ui:comfy-ui "$target" 2>/dev/null || true
        ${pkgs.coreutils}/bin/chmod 0664 "$target"
      '')
    downloadModels);

  modelDirs = lib.unique (map (m: "models/${m.folder}") (lib.attrValues resolvedModels));
  # `workflows` folder → user/default/workflows (ComfyUI's workflow dir).
  workflowDirs =
    if lib.any (m: m.folder == "workflows") (lib.attrValues resolvedModels)
    then [ "user" "user/default" "user/default/workflows" ]
    else [ ];

  # Symlink commands for custom nodes. The `[ ! -e ]` guard leaves any existing
  # node alone (so runtime-managed nodes installed by ComfyUI-Manager — real git
  # clones — are never clobbered), but a symlink pointing at an OLD store path
  # (stale declarative pin) is re-linked to the new one so pin bumps take effect.
  customNodeLinks = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: src:
      let
        srcPath = builtins.toString src;
        srcArg = lib.escapeShellArg srcPath;
        target = "${cfg.dataDir}/custom_nodes/${lib.escapeShellArg name}";
      in
      ''
        target="${target}"
        if [ ! -e "$target" ]; then
          ln -sfn ${srcArg} "$target"
          echo "custom_nodes: linked ${name}"
        elif [ -L "$target" ] && [ "$(readlink "$target")" != "${srcPath}" ]; then
          ln -sfn ${srcArg} "$target"
          echo "custom_nodes: refreshed ${name}"
        fi
      '')
    customNodeSrcs);

  # ── Project-local opencode config (.opencode/ in the data dir) ───────────
  # Only visible to opencode sessions run FROM this directory, never other
  # projects (e.g. nixos-config) — for cleanliness, not permission.
  # Wired only when opencode is enabled for the primary user.
  me = flake.config.me.username;
  opencodeEnabled =
    cfg.opencode.enable
    && (if builtins.hasAttr "home-manager" config
    then config.home-manager.users.${me}.my.programs.opencode.enable or false
    else false);

  opencodeDir = "${cfg.dataDir}/.opencode";
  # Default MCP command: artokun/comfyui-mcp (local-first, drives this
  # instance; runtime-fetched via npx like the repo's uvx-based MCP servers).
  # The command is wrapped in a script that puts nodejs on PATH: the Nix `npx`
  # wrapper itself runs via an absolute shebang, but the npx-downloaded
  # comfyui-mcp binary is `#!/usr/bin/env node` — without node on PATH the MCP
  # server fails to spawn with `env: 'node': No such file or directory`.
  mcpCommand =
    if cfg.opencode.mcp.command != [ ]
    then cfg.opencode.mcp.command
    else [
      (pkgs.writeShellScriptBin "comfyui-mcp" ''
        export PATH="${pkgs.nodejs_22}/bin:$PATH"
        exec "${pkgs.nodejs_22}/bin/npx" -y comfyui-mcp@0.52.167
      '')
    ];

  opencodeJson = pkgs.writeText "comfyui-opencode.json" (builtins.toJSON {
    mcp = lib.optionalAttrs cfg.opencode.mcp.enable {
      ${cfg.opencode.mcp.name} = {
        type = "local";
        command = mcpCommand;
        environment = {
          COMFYUI_URL = "http://127.0.0.1:${toString cfg.port}";
          COMFYUI_PATH = cfg.dataDir;
        } // cfg.opencode.mcp.environment;
        enabled = true;
      };
    };
  });

  opencodeSkill = pkgs.writeText "SKILL.md" (builtins.readFile ./opencode/skill.md);
  opencodeStatusCmd = pkgs.writeText "comfyui-status.md" (builtins.readFile ./opencode/commands/status.md);
  opencodeWorkflowCmd = pkgs.writeText "comfyui-workflow.md" (builtins.readFile ./opencode/commands/workflow.md);
  opencodeWorkspaceCmd = pkgs.writeText "comfyui-workspace.md" (builtins.readFile ./opencode/commands/workspace.md);
  opencodeApiTool = pkgs.writeText "comfyui-api.ts" (builtins.readFile ./opencode/tools/comfyui-api.ts);
  opencodeWorkspaceTool = pkgs.writeText "comfyui-workspace.ts" (builtins.readFile ./opencode/tools/comfyui-workspace.ts);
  opencodeWorkspacePlugin = pkgs.writeText "comfyui-workspace.ts" (builtins.readFile ./opencode/plugin/workspace.ts);

  # Seeded payload for the writable workspace state file. Written by the setup
  # script as a real file (NOT symlinked — the store-rendered file is read-only;
  # the state must be writable by agents/humans).
  opencodeWorkspaceSeed = builtins.toJSON {
    workflow = "user/default/workflows/Test Workfloww.json";
    set_by = "seed";
    updated = "1970-01-01T00:00:00.000Z";
  };

  opencodeLinks = lib.optionalString opencodeEnabled ''
        ${pkgs.coreutils}/bin/install -d -o comfy-ui -g comfy-ui -m 0770 \
          ${opencodeDir} ${opencodeDir}/skills/comfyui-development ${opencodeDir}/commands ${opencodeDir}/tools ${opencodeDir}/plugin
        ln -sfn ${opencodeJson} ${opencodeDir}/opencode.json
        ln -sfn ${opencodeSkill} ${opencodeDir}/skills/comfyui-development/SKILL.md
        ln -sfn ${opencodeStatusCmd} ${opencodeDir}/commands/comfyui-status.md
        ln -sfn ${opencodeWorkflowCmd} ${opencodeDir}/commands/comfyui-workflow.md
        ln -sfn ${opencodeWorkspaceCmd} ${opencodeDir}/commands/comfyui-workspace.md
        ln -sfn ${opencodeApiTool} ${opencodeDir}/tools/comfyui-api.ts
        ln -sfn ${opencodeWorkspaceTool} ${opencodeDir}/tools/comfyui-workspace.ts
        ln -sfn ${opencodeWorkspacePlugin} ${opencodeDir}/plugin/comfyui-workspace.ts
        # Writable workspace state (seeded to the named workflow; plugin/agents can
        # update it). Created as a real file owned by the primary user so agents can
        # write it without root. Seeded to the current Test Workflow initially.
        if [ ! -f ${opencodeDir}/workspace.json ]; then
          ${pkgs.coreutils}/bin/install -o comfy-ui -g comfy-ui -m 0660 /dev/stdin ${opencodeDir}/workspace.json <<'SEED'
    ${opencodeWorkspaceSeed}
    SEED
          echo "workspace: seeded ${opencodeDir}/workspace.json"
        else
          echo "workspace: keeping existing ${opencodeDir}/workspace.json"
        fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    services.comfyUi = {
      enable = true;
      inherit (cfg) dataDir;
      listenHost = cfg.listenHost;
      listenPort = cfg.port;
      package = comfyUiPackage; # v0.29.2 (repo-local) — see ./comfy/
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    my.services.proxy.upstreams.comfyui = {
      port = cfg.port;
      path = "/comfyui/";
      # The civitai-comfy-nodes pack frontend fetches ROOT-RELATIVE URLs
      # (/civitai/catalog/*, /civitai/auth/*, /civitai/workflows/*, ...). Under
      # the path-prefixed proxy those bypass the /comfyui/ handle and would hit
      # Caddy's catch-all 404 (empty body → "JSON.parse: unexpected end of
      # data" in the catalog/civiti gallery). Route them back to ComfyUI.
      extraLocations = [
        # Caddyfile requires block bodies on their own lines (no single-line
        # `handle { ... }`) — keep this multi-line or the Caddyfile fails to
        # adapt ("Unexpected next token after '{' on same line").
        ''
          handle /civitai/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
      ];
    };

    # Override the upstream module's ExecStart to inject our CLI args
    systemd.services.comfy-ui.script = lib.mkForce (
      let
        bin = config.services.comfyUi.package or pkgs.stable-diffusion-webui.comfy.cuda;
      in
      ''
        # Writable HOME (service user's passwd HOME is /var/empty): the
        # civitai-comfy-nodes pack persists auth/session under ~/.civitai/ and
        # pip caches under ~/.cache — both fail with EROFS on /var/empty.
        export HOME="${cfg.dataDir}"
        export HF_HOME="$CACHE_DIRECTORY/huggingface/hub"
        ${civitaiLinkEnv}
        ${ggufLinkEnv}
        ${managerPipEnv}

        mkdir -p ${cfg.dataDir}/custom_nodes
        ${customNodeLinks}

        exec ${bin}/bin/comfy-ui \
          --base-directory ${lib.escapeShellArg cfg.dataDir} \
          ${cliArgs}
      ''
    );

    # Relax systemd sandboxing — the upstream module's strict ProtectHome/PrivateMounts
    # cause EXIT_NAMESPACE (226) on this kernel. The service needs to download models
    # and manage custom nodes at runtime.
    systemd.services.comfy-ui.serviceConfig = {
      ProtectHome = lib.mkForce "tmpfs";
      PrivateMounts = lib.mkForce false;
      # UMask 0007: dirs/files created by the service get group access so the
      # primary user (in the comfy-ui group below) can read outputs/workflows
      # and drop files into models/input without sudo.
      UMask = "0007";
    };

    # Registered the agenix Civitai key with the civitai-comfy-nodes pack on
    # boot. The pack validates via POST /civitai/auth/api-key and persists to
    # $HOME/.civitai/comfy-settings.json (writable since the service exports
    # HOME=dataDir). Retries until ComfyUI's aiohttp routes are registered
    # (they come up a few seconds after the exec starts). Idempotent: re-POSTs
    # on every boot so a rotated key is reapplied and a wiped user-dir is
    # re-seeded.
    systemd.services.comfy-ui-civitai-auth = lib.mkIf (cfg.civitaiApiKeyPath != null) {
      description = "Register Civitai API key with civitai-comfy-nodes";
      wantedBy = [ "multi-user.target" ];
      after = [ "comfy-ui.service" ];
      requires = [ "comfy-ui.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        KEY_FILE=${lib.escapeShellArg cfg.civitaiApiKeyPath}
        ${pkgs.coreutils}/bin/install -d -o comfy-ui -g comfy-ui -m 0770 ${cfg.dataDir}/.civitai
        # Civitai API keys are [A-Za-z0-9._-] — reject anything else so the key
        # can't break out of the JSON payload below.
        KEY=$(${pkgs.coreutils}/bin/cat "$KEY_FILE")
        if ! ${pkgs.gnugrep}/bin/grep -qE '^[A-Za-z0-9._-]+$' <<<"$KEY"; then
          echo "civitai-auth: refusing key with unexpected characters" >&2
          exit 1
        fi
        PAYLOAD=$(${pkgs.coreutils}/bin/printf '{"apiKey":"%s"}' "$KEY")
        ok=""
        for i in $(${pkgs.coreutils}/bin/seq 1 60); do
          resp=$(${pkgs.curl}/bin/curl -s --max-time 10 -o /tmp/civitai-auth.out -w '%{http_code}' -H 'Content-Type: application/json' -d "$PAYLOAD" http://127.0.0.1:${toString cfg.port}/civitai/auth/api-key) || true
          if [ "$resp" = "200" ] && ${pkgs.gnugrep}/bin/grep -q '"ok"' /tmp/civitai-auth.out 2>/dev/null; then
            ok=1
            break
          fi
          sleep 5
        done
        if [ -z "$ok" ]; then
          echo "civitai-auth: failed to register Civitai key after 60 attempts (last http=$resp: $(cat /tmp/civitai-auth.out 2>/dev/null))" >&2
          exit 1
        fi
        echo "civitai-auth: Civitai API key registered with civitai-comfy-nodes"
      '';
    };

    # dataDir + user-touch subdirs are created by a ROOT oneshot, NOT tmpfiles:
    # systemd-tmpfiles refuses to descend a path whose parent is owned by a
    # non-root user ("Detected unsafe path transition /mnt/data (owned by
    # seanc)") and silently skips the rule — same failure mode documented for
    # minecraft-server. Mode 0770 comfy-ui:comfy-ui + primary-user group
    # membership (below) gives the user browse + drop access to the whole tree.
    # models/ is pre-created 0770 but its contents are NOT chmod -R'd (they can
    # be GBs; the service only needs to read them — the user drops files in).
    systemd.services.comfy-ui-prepare-dirs = {
      description = "Create ComfyUI data directories";
      wantedBy = [ "multi-user.target" ];
      before = [ "comfy-ui.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.coreutils}/bin/install -d -o comfy-ui -g comfy-ui -m 0770 ${cfg.dataDir}
        ${lib.concatStringsSep "\n" (map (d: ''
          ${pkgs.coreutils}/bin/install -d -o comfy-ui -g comfy-ui -m 0770 ${cfg.dataDir}/${d}
        '') ([ "input" "temp" "user" "custom_nodes" "models" "models/checkpoints" "models/loras" "models/vae" "models/clip" "output" ] ++ modelDirs ++ workflowDirs ++ lib.optional cfg.enableManager "python-site-packages"))}
        # Self-heal group access on user-data files (workflows, settings, inputs);
        # models/ is excluded — could be GBs and the service only needs to read it.
        ${pkgs.coreutils}/bin/chmod -R g+rwX \
          ${cfg.dataDir}/user ${cfg.dataDir}/input ${cfg.dataDir}/temp ${cfg.dataDir}/custom_nodes ${lib.optionalString cfg.enableManager (cfg.dataDir + "/python-site-packages")} 2>/dev/null || true
        # Declarative models: store mode = symlinked store-pinned FODs;
        # download mode = resumable curl into the data dir (real file).
        ${storeModelLinks}
        ${downloadModelScript}
        # Project-local opencode config (.opencode/) — store-rendered files,
        # symlinked so updates propagate on rebuild; only when opencode is on.
        ${opencodeLinks}
      '';
    };

    # Primary user in the comfy-ui group: dataDir is 0770 comfy-ui:comfy-ui,
    # so group membership gives the user read/write access without sudo.
    users.groups.comfy-ui.members = [ flake.config.me.username ];

    # Contribute the module's opencode skills to the PRIMARY user's MAIN
    # opencode config (`my.homeManager.extraConfig.my.programs.opencode.skills`,
    # same mechanism the minecraft/pz modules use) — they land in
    # ~/.config/opencode/skills/<name>/SKILL.md, available in ANY project,
    # alongside the other custom skills. Gategory: only when this module's
    # opencode integration is on (the homeManager module makes this inert on
    # hosts where opencode isn't enabled).
    my.homeManager.extraConfig.my.programs.opencode.skills =
      lib.mkIf cfg.opencode.enable cfg.opencode.skills;
  };
}
