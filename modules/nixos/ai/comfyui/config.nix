{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.comfyui;

  # Curated, pre-pinned node catalog (url + rev + sha256, fetchSubmodules=true
  # to match the prefetch). `presets` selects names from it; an explicit
  # `customNodes` entry with the same attr name overrides the catalog pin.
  catalog = import ./catalog.nix;

  presetNodes = lib.listToAttrs (map (name: {
    inherit name;
    value = {
      enable = true;
      url = catalog.${name}.url;
      rev = catalog.${name}.rev;
      sha256 = catalog.${name}.sha256;
      fetchSubmodules = true;
    };
  }) cfg.presets);

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
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    my.services.proxy.upstreams.comfyui = {
      port = cfg.port;
      path = "/comfyui/";
    };

    # Override the upstream module's ExecStart to inject our CLI args
    systemd.services.comfy-ui.script = lib.mkForce (
      let
        bin = config.services.comfyUi.package or pkgs.stable-diffusion-webui.comfy.cuda;
      in
      ''
        export HF_HOME="$CACHE_DIRECTORY/huggingface/hub"
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
        '') ([ "input" "temp" "user" "custom_nodes" "models" "models/checkpoints" "models/loras" "models/vae" "models/clip" "output" ] ++ lib.optional cfg.enableManager "python-site-packages"))}
        # Self-heal group access on user-data files (workflows, settings, inputs);
        # models/ is excluded — could be GBs and the service only needs to read it.
        ${pkgs.coreutils}/bin/chmod -R g+rwX \
          ${cfg.dataDir}/user ${cfg.dataDir}/input ${cfg.dataDir}/temp ${cfg.dataDir}/custom_nodes ${lib.optionalString cfg.enableManager (cfg.dataDir + "/python-site-packages")} 2>/dev/null || true
        # Project-local opencode config (.opencode/) — store-rendered files,
        # symlinked so updates propagate on rebuild; only when opencode is on.
        ${opencodeLinks}
      '';
    };

    # Primary user in the comfy-ui group: dataDir is 0770 comfy-ui:comfy-ui,
    # so group membership gives the user read/write access without sudo.
    users.groups.comfy-ui.members = [ flake.config.me.username ];
  };
}
