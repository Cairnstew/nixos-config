{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.comfyui;

  enabledNodes = lib.filterAttrs (_: n: n.enable) cfg.customNodes;

  # Fetch custom node git repos at build time using builtins.fetchGit.
  # Pinned by ref (branch/tag/commit). No hash needed — evaluation-time fetch
  # is cached in the Nix store.
  customNodeSrcs = lib.mapAttrs
    (name: node:
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

  # Symlink commands for custom nodes
  customNodeLinks = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: src: ''
      target="${cfg.dataDir}/custom_nodes/${lib.escapeShellArg name}"
      if [ ! -e "$target" ]; then
        ln -sfn ${lib.escapeShellArg (builtins.toString src)} "$target"
        echo "custom_nodes: linked ${name}"
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
  mcpCommand = if cfg.opencode.mcp.command != [ ]
    then cfg.opencode.mcp.command
    else [ "${pkgs.nodejs_22}/bin/npx" "-y" "comfyui-mcp@0.52.167" ];

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
        '') [ "input" "temp" "user" "custom_nodes" "models" "models/checkpoints" "models/loras" "models/vae" "models/clip" "output" ])}
        # Self-heal group access on user-data files (workflows, settings, inputs);
        # models/ is excluded — could be GBs and the service only needs to read it.
        ${pkgs.coreutils}/bin/chmod -R g+rwX \
          ${cfg.dataDir}/user ${cfg.dataDir}/input ${cfg.dataDir}/temp ${cfg.dataDir}/custom_nodes 2>/dev/null || true
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
