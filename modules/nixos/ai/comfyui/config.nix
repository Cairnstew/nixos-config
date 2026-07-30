{ config, lib, pkgs, ... }:
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
    };

    # Ensure dataDir exists when it's not the default /var/lib/comfy-ui
    systemd.tmpfiles.rules = lib.optional (cfg.dataDir != "/var/lib/comfy-ui")
      "d ${cfg.dataDir} 0700 comfy-ui comfy-ui -";
  };
}
