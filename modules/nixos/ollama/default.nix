{ config, pkgs, lib, ... }:

let
  cfg = config.my.services.ollama;
  backendBin = if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";

  # ---------------------------------------------------------------------------
  # ollama-mcp-wrapper derivation
  #
  # Packages supergateway (HTTP SSE bridge) + ollama-mcp-server (stdio MCP).
  # supergateway spawns ollama-mcp-server as a child process over stdio and
  # exposes it on an HTTP SSE port so remote Cline clients can connect.
  #
  # Architecture:
  #   Cline --SSE--> supergateway:3100 --stdio--> ollama-mcp-server --> Ollama
  #
  # To update package versions, regenerate ollama-mcp-package-lock.json:
  #   cd /tmp && mkdir wrap && cd wrap
  #   echo '{"dependencies":{"ollama-mcp-server":"X.Y.Z","supergateway":"A.B.C"}}' \
  #     > package.json
  #   npm install --package-lock-only --ignore-scripts
  #   cp package-lock.json /path/to/nixos-config/modules/services/ollama-mcp-package-lock.json
  # Then update npmDepsHash by setting it to lib.fakeHash, running nixos-rebuild
  # (it will fail and print the correct hash), and replacing it below.
  # ---------------------------------------------------------------------------
  ollamaMcpWrapper = pkgs.buildNpmPackage {
    pname   = "ollama-mcp-wrapper";
    version = "1.0.0";

    src = pkgs.runCommand "ollama-mcp-wrapper-src" {} ''
      mkdir -p $out
      cp ${pkgs.writeText "package.json" (builtins.toJSON {
        name    = "ollama-mcp-wrapper";
        version = "1.0.0";
        dependencies = {
          "ollama-mcp-server" = "1.1.0";
          "supergateway"      = "3.4.3";
        };
      })} $out/package.json
      cp ${./mcp-package-lock.json} $out/package-lock.json
    '';

    # Run: nixos-rebuild switch 2>&1 | grep "got:"
    # to find the correct hash after setting this to lib.fakeHash.
    npmDepsHash = "sha256-2q0ImcLtkJmtHTGnEfCYG/g0n7ysUWe7g00qncNSwmA=";

    dontNpmBuild = true;  # both packages ship pre-built JS

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      # Install node_modules directly to the lib path
      mkdir -p $out/lib/node_modules
      cp -r . $out/lib/node_modules/ollama-mcp-wrapper

      # Expose supergateway
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/supergateway \
        --add-flags "$out/lib/node_modules/ollama-mcp-wrapper/node_modules/supergateway/dist/index.js"

      runHook postInstall
    '';
  };

  # Absolute path to ollama-mcp-server's pre-built entry point inside node_modules
  ollamaMcpServerBin =
    "${ollamaMcpWrapper}/lib/node_modules/ollama-mcp-wrapper/node_modules/ollama-mcp-server/build/index.js";

in
{
  options.my.services.ollama = {
    enable = lib.mkEnableOption "Ollama OCI container service";

    image = lib.mkOption {
      type    = lib.types.str;
      default = "ollama/ollama:latest";
      description = "Docker image to use for the Ollama container.";
    };

    dataDir = lib.mkOption {
      type    = lib.types.str;
      default = "/var/lib/ollama";
      description = "Host path to persist Ollama model data.";
    };

    port = lib.mkOption {
      type    = lib.types.port;
      default = 11434;
      description = "Host port to expose the Ollama API on.";
    };

    host = lib.mkOption {
      type    = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        IP address Ollama listens on inside the container (sets OLLAMA_HOST).
        Use "0.0.0.0" to accept connections from outside the host.
      '';
    };

    backend = lib.mkOption {
      type    = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        freeformType = with lib.types; attrsOf anything;
        options = {
          name           = lib.mkOption { type = lib.types.str; description = "Display name."; };
          tools          = lib.mkOption { type = lib.types.bool; default = false; };
          opencode_default = lib.mkOption { type = lib.types.bool; default = false; };
          numCtx         = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          temperature    = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          think          = lib.mkOption { type = lib.types.nullOr lib.types.bool;  default = null; };
          topK           = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          topP           = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          repeatPenalty  = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          numPredict     = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          seed           = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          systemPrompt   = lib.mkOption { type = lib.types.nullOr lib.types.str;   default = null; };
          template       = lib.mkOption { type = lib.types.nullOr lib.types.str;   default = null; };
        };
      });
      default = {};
      description = "Attrset of models to pull and configure after the container starts.";
    };

    gpu = {
      enable          = lib.mkEnableOption "GPU passthrough for the Ollama container";
      type            = lib.mkOption { type = lib.types.enum [ "nvidia" "amd" "intel" ]; default = "nvidia"; };
      nvidiaDeviceArg = lib.mkOption { type = lib.types.str;  default = "all"; };
      healthCheck     = lib.mkOption { type = lib.types.bool; default = true; };
    };

    network = {
      name  = lib.mkOption { type = lib.types.str; default = "ollama-net"; };
      alias = lib.mkOption { type = lib.types.str; default = "ollama"; };
    };

    extraVolumes        = lib.mkOption { type = lib.types.listOf lib.types.str;        default = []; };
    extraOptions        = lib.mkOption { type = lib.types.listOf lib.types.str;        default = []; };
    environmentVariables = lib.mkOption { type = lib.types.attrsOf lib.types.str;      default = {}; };
    logDriver           = lib.mkOption { type = lib.types.str;                         default = "journald"; };
    autoPrune           = lib.mkOption { type = lib.types.bool;                        default = true; };

    restart = {
      policy      = lib.mkOption { type = lib.types.str; default = "always"; };
      maxDelaySec = lib.mkOption { type = lib.types.str; default = "1m"; };
      delaySec    = lib.mkOption { type = lib.types.str; default = "100ms"; };
      steps       = lib.mkOption { type = lib.types.int; default = 9; };
    };

    performance = {
      numParallel     = lib.mkOption { type = lib.types.nullOr lib.types.int;  default = 1; };
      maxLoadedModels = lib.mkOption { type = lib.types.nullOr lib.types.int;  default = 1; };
      maxVram         = lib.mkOption { type = lib.types.nullOr lib.types.int;  default = null; };
      flashAttention  = lib.mkOption { type = lib.types.bool;                  default = false; };
    };

    # ---------------------------------------------------------------------------
    # MCP server options
    # ---------------------------------------------------------------------------
    mcp = {
      enable = lib.mkEnableOption "Ollama MCP SSE server for Cline (supergateway + ollama-mcp-server)";

      port = lib.mkOption {
        type    = lib.types.port;
        default = 3100;
        description = ''
          Port the SSE server listens on. Cline connects to http://<host>:<port>/sse.
        '';
      };

      openFirewall = lib.mkOption {
        type    = lib.types.bool;
        default = false;
        description = ''
          Open cfg.mcp.port in the NixOS firewall.
          Not needed when Tailscale routes traffic directly between nodes.
        '';
      };

      logLevel = lib.mkOption {
        type    = lib.types.enum [ "debug" "info" "none" ];
        default = "info";
        description = "supergateway log verbosity.";
      };
    };
  };

  # =============================================================================
  config = lib.mkIf cfg.enable {

    assertions = [{
      assertion = (lib.length (lib.filter
        (tag: cfg.models.${tag}.opencode_default)
        (lib.attrNames cfg.models)) <= 1);
      message = "my.services.ollama.models: only one model may have opencode_default = true";
    }];

    virtualisation.docker = lib.mkIf (cfg.backend == "docker") {
      enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault cfg.autoPrune;
    };

    virtualisation.podman = lib.mkIf (cfg.backend == "podman") {
      enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault cfg.autoPrune;
    };

    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0755 root root -" ];

    virtualisation.oci-containers.backend = cfg.backend;

    virtualisation.oci-containers.containers."ollama" = {
      image = cfg.image;

      volumes = [ "${cfg.dataDir}:/root/.ollama:rw" ] ++ cfg.extraVolumes;

      ports = [ "${toString cfg.port}:11434/tcp" ];

      environment = lib.filterAttrs (_: v: v != "") ({
        OLLAMA_HOST              = cfg.host;
        OLLAMA_NUM_PARALLEL      = lib.optionalString (cfg.performance.numParallel     != null) (toString cfg.performance.numParallel);
        OLLAMA_MAX_LOADED_MODELS = lib.optionalString (cfg.performance.maxLoadedModels != null) (toString cfg.performance.maxLoadedModels);
        OLLAMA_MAX_VRAM          = lib.optionalString (cfg.performance.maxVram         != null) (toString cfg.performance.maxVram);
        OLLAMA_FLASH_ATTENTION   = if cfg.performance.flashAttention then "1" else "";
      } // cfg.environmentVariables);

      log-driver = cfg.logDriver;

      extraOptions = lib.flatten [
        (lib.optionals cfg.gpu.enable (
          if cfg.gpu.type == "nvidia" then
            [ "--device=nvidia.com/gpu=${cfg.gpu.nvidiaDeviceArg}" ]
            ++ lib.optionals cfg.gpu.healthCheck [
              "--health-cmd=nvidia-smi"
              "--health-interval=10s"
              "--health-retries=3"
              "--health-start-period=1m0s"
              "--health-timeout=5s"
            ]
          else if cfg.gpu.type == "amd"   then [ "--device=/dev/kfd" "--device=/dev/dri" ]
          else if cfg.gpu.type == "intel" then [ "--device=/dev/dri" ]
          else []
        ))
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
        cfg.extraOptions
      ];
    };

    systemd.services."${cfg.backend}-ollama" = {
      serviceConfig = {
        Restart            = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec         = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps       = lib.mkOverride 90 cfg.restart.steps;
        ExecStartPre       = lib.mkOverride 90
          "${pkgs.writeShellScript "ollama-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";
      };
    };

    systemd.services."ollama-pull-models" = lib.mkIf (cfg.models != {}) {
      description = "Pull and configure Ollama models";
      after    = [ "${cfg.backend}-ollama.service" ];
      requires = [ "${cfg.backend}-ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        Restart         = "on-failure";
        RestartSec      = "10s";
      };

      script =
        let
          waitCmd = ''
            echo "Waiting for Ollama to become ready..."
            until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/api/tags > /dev/null 2>&1; do
              echo "  ...not ready yet, retrying in 2s"
              sleep 2
            done
            echo "Ollama is ready."
          '';

          paramLines = mcfg: lib.concatStringsSep "" (lib.filter (s: s != "") [
            (lib.optionalString (mcfg.numCtx        != null) "printf 'PARAMETER num_ctx %s\\n'        '${toString mcfg.numCtx}'        >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.temperature   != null) "printf 'PARAMETER temperature %s\\n'    '${toString mcfg.temperature}'   >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.topK          != null) "printf 'PARAMETER top_k %s\\n'          '${toString mcfg.topK}'          >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.topP          != null) "printf 'PARAMETER top_p %s\\n'          '${toString mcfg.topP}'          >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.repeatPenalty != null) "printf 'PARAMETER repeat_penalty %s\\n' '${toString mcfg.repeatPenalty}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.numPredict    != null) "printf 'PARAMETER num_predict %s\\n'    '${toString mcfg.numPredict}'    >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.seed          != null) "printf 'PARAMETER seed %s\\n'           '${toString mcfg.seed}'          >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.think         != null) "printf 'PARAMETER think %s\\n'          '${if mcfg.think == true then "true" else "false"}' >> \"$MODELFILE\"\n")
          ]);

          hasModelfile = mcfg:
            mcfg.numCtx != null || mcfg.temperature != null || mcfg.topK != null ||
            mcfg.topP   != null || mcfg.repeatPenalty != null || mcfg.numPredict != null ||
            mcfg.seed   != null || mcfg.think != null || mcfg.systemPrompt != null || mcfg.template != null;

          modelCmds = lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: mcfg:
            let safeName = builtins.replaceStrings [ ":" "/" ] [ "-" "-" ] tag;
            in
            ''echo "--- Pulling model: ${tag} ---"
              ${backendBin} exec ollama ollama pull ${lib.escapeShellArg tag}
            '' + lib.optionalString (hasModelfile mcfg) ''
              echo "Applying Modelfile for ${tag} -> '${safeName}'..."
              MODELFILE=$(mktemp)
              printf 'FROM %s\n' ${lib.escapeShellArg tag} > "$MODELFILE"
              ${paramLines mcfg}
            '' + lib.optionalString (mcfg.systemPrompt != null) ''
              printf 'SYSTEM """\n' >> "$MODELFILE"
              cat >> "$MODELFILE" << 'OLLAMA_SYSTEM_EOF'
              ${mcfg.systemPrompt}
              OLLAMA_SYSTEM_EOF
              printf '"""\n' >> "$MODELFILE"
            '' + lib.optionalString (mcfg.template != null) ''
              printf 'TEMPLATE """\n' >> "$MODELFILE"
              cat >> "$MODELFILE" << 'OLLAMA_TEMPLATE_EOF'
              ${mcfg.template}
              OLLAMA_TEMPLATE_EOF
              printf '"""\n' >> "$MODELFILE"
            '' + lib.optionalString (hasModelfile mcfg) ''
              ${backendBin} cp "$MODELFILE" ollama:/tmp/Modelfile.${safeName}
              ${backendBin} exec ollama ollama create ${lib.escapeShellArg safeName} -f /tmp/Modelfile.${safeName}
              rm -f "$MODELFILE"
              echo "Model '${safeName}' created."
            ''
          ) cfg.models);
        in
          waitCmd + "\n" + modelCmds;
    };

    # ---------------------------------------------------------------------------
    # MCP SSE service
    # ---------------------------------------------------------------------------
    systemd.services."ollama-mcp-server" = lib.mkIf cfg.mcp.enable {
      description = "Ollama MCP SSE server (supergateway → ollama-mcp-server) for Cline";

      after    = [ "${cfg.backend}-ollama.service" ]
                 ++ lib.optional (cfg.models != {}) "ollama-pull-models.service";
      requires = [ "${cfg.backend}-ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        # ollama-mcp-server uses this to reach the Ollama REST API
        OLLAMA_HOST = "http://127.0.0.1:${toString cfg.port}";
      };

      serviceConfig = {
        Type       = "simple";
        Restart    = "always";
        RestartSec = "5s";

        # supergateway spawns ollama-mcp-server as a child over stdio,
        # then serves SSE on 0.0.0.0:<port> (Node default for app.listen(port)).
        ExecStart = lib.escapeShellArgs [
          "${ollamaMcpWrapper}/bin/supergateway"
          "--port"     (toString cfg.mcp.port)
          "--logLevel" cfg.mcp.logLevel
          "--stdio"    "${pkgs.nodejs_22}/bin/node ${ollamaMcpServerBin}"
        ];

        NoNewPrivileges = true;
        PrivateTmp      = true;
        ProtectSystem   = "strict";
        ProtectHome     = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.mcp.enable && cfg.mcp.openFirewall) [ cfg.mcp.port ];
  };
}
