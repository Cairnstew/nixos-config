# modules/services/ollama.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.my.services.ollama;
  backendBin = if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";

  ollamaMcpWrapper = pkgs.buildNpmPackage {
    pname   = "ollama-mcp-wrapper";
    version = "1.0.0";
    nodejs  = pkgs.nodejs_22;

    src = pkgs.runCommand "ollama-mcp-wrapper-src" {} ''
      mkdir -p $out
      cp ${pkgs.writeText "package.json" (builtins.toJSON {
        name    = "ollama-mcp-wrapper";
        version = "1.0.0";
        dependencies = {
          "ollama-mcp-server" = "1.1.0";
          # 3.4.3 has a single-client SSE crash; we use streamableHttp
          # transport to avoid it. Bump when a fix lands upstream.
          "supergateway"      = "3.4.3";
        };
      })} $out/package.json
      cp ${./mcp-package-lock.json} $out/package-lock.json
    '';

    npmDepsHash = "sha256-2q0ImcLtkJmtHTGnEfCYG/g0n7ysUWe7g00qncNSwmA=";

    dontNpmBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules
      cp -r . $out/lib/node_modules/ollama-mcp-wrapper
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/supergateway \
        --add-flags "$out/lib/node_modules/ollama-mcp-wrapper/node_modules/supergateway/dist/index.js"
      runHook postInstall
    '';
  };

  ollamaMcpServerBin =
    "${ollamaMcpWrapper}/lib/node_modules/ollama-mcp-wrapper/node_modules/ollama-mcp-server/build/index.js";

  # The host-side Ollama API URL — always 127.0.0.1 because the MCP server
  # runs on the host and reaches Ollama via the published port mapping,
  # regardless of what address Ollama binds to inside the container.
  ollamaHostUrl = "http://127.0.0.1:${toString cfg.port}";

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
        # freeformType allows ad-hoc keys without breaking evaluation.
        freeformType = with lib.types; attrsOf anything;
        options = {
          name             = lib.mkOption { type = lib.types.str;              description = "Display name."; };
          tools            = lib.mkOption { type = lib.types.bool;             default = false; description = "Model supports tool/function calling."; };
          # ── cross-module default flags ────────────────────────────────────
          opencode_default = lib.mkOption { type = lib.types.bool;             default = false; description = "Use as default model in opencode."; };
          aider_default    = lib.mkOption { type = lib.types.bool;             default = false; description = "Use as default model in aider."; };
          cline_default    = lib.mkOption { type = lib.types.bool;             default = false; description = "Use as default model in Cline."; };
          # ── Modelfile parameters ──────────────────────────────────────────
          numCtx        = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; description = "Context window size (num_ctx)."; };
          temperature   = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; description = "Sampling temperature. Use 0–0.2 for agentic/tool tasks."; };
          think         = lib.mkOption { type = lib.types.nullOr lib.types.bool;  default = null; description = "Enable chain-of-thought reasoning (supported models only)."; };
          topK          = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          topP          = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          repeatPenalty = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          numPredict    = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          seed          = lib.mkOption { type = lib.types.nullOr lib.types.int;   default = null; };
          systemPrompt  = lib.mkOption { type = lib.types.nullOr lib.types.str;   default = null; };
          template      = lib.mkOption { type = lib.types.nullOr lib.types.str;   default = null; };
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

    extraVolumes         = lib.mkOption { type = lib.types.listOf lib.types.str;   default = []; };
    extraOptions         = lib.mkOption { type = lib.types.listOf lib.types.str;   default = []; };
    environmentVariables = lib.mkOption { type = lib.types.attrsOf lib.types.str;  default = {}; };
    logDriver            = lib.mkOption { type = lib.types.str;                    default = "journald"; };
    autoPrune            = lib.mkOption { type = lib.types.bool;                   default = true; };

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

    mcp = {
      enable = lib.mkEnableOption "Ollama MCP server for Cline (supergateway + ollama-mcp-server)";

      port = lib.mkOption {
        type    = lib.types.port;
        default = 3100;
        description = ''
          Port the MCP server listens on.
          Cline connects via streamableHttp at
          <literal>http://&lt;host&gt;:&lt;port&gt;/mcp</literal>.
        '';
      };

      openFirewall = lib.mkOption {
        type    = lib.types.bool;
        default = false;
        description = ''
          Open <option>mcp.port</option> in the NixOS firewall.
          Not needed when Tailscale routes traffic directly between nodes.
        '';
      };

      logLevel = lib.mkOption {
        type    = lib.types.enum [ "debug" "info" "none" ];
        default = "info";
        description = "supergateway log verbosity.";
      };
    };

    # ── Test suite ────────────────────────────────────────────────────────────
    tests = {
      enable = lib.mkEnableOption "Ollama smoke-test suite (ollama-smoke-test oneshot + ollama-test CLI)";

      generateModel = lib.mkOption {
        type    = lib.types.str;
        default = "";
        description = ''
          Model tag to use for the generate roundtrip in the smoke test.
          Defaults to the first model with opencode_default, then aider_default,
          then the first model in the attrset.  Override explicitly if needed.
        '';
      };
    };
  };

  # =============================================================================
  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = lib.length (lib.filter
          (tag: cfg.models.${tag}.opencode_default)
          (lib.attrNames cfg.models)) <= 1;
        message = "my.services.ollama.models: only one model may have opencode_default = true";
      }
      {
        assertion = lib.length (lib.filter
          (tag: cfg.models.${tag}.cline_default)
          (lib.attrNames cfg.models)) <= 1;
        message = "my.services.ollama.models: only one model may have cline_default = true";
      }
      {
        assertion = lib.length (lib.filter
          (tag: cfg.models.${tag}.aider_default)
          (lib.attrNames cfg.models)) <= 1;
        message = "my.services.ollama.models: only one model may have aider_default = true";
      }
    ];

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

    # ---------------------------------------------------------------------------
    # Container service — network creation + restart policy + Layer-1a probe
    # ---------------------------------------------------------------------------
    systemd.services."${cfg.backend}-ollama" = {
      serviceConfig = {
        Restart            = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec         = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps       = lib.mkOverride 90 cfg.restart.steps;

        ExecStartPre = lib.mkOverride 90
          "${pkgs.writeShellScript "ollama-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";

        # Layer 1a: verify the API is reachable before systemd marks the unit active.
        ExecStartPost = lib.mkOverride 90
          "${pkgs.writeShellScript "ollama-container-probe" ''
            echo "[ollama probe] waiting for API..."
            for i in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.curl}/bin/curl -sf \
                  http://127.0.0.1:${toString cfg.port}/api/tags > /dev/null 2>&1; then
                echo "[ollama probe] API reachable (attempt $i)"
                exit 0
              fi
              sleep 1
            done
            echo "[ollama probe] FAIL: API not reachable after 30s" >&2
            exit 1
          ''}";
      };
    };

    # ---------------------------------------------------------------------------
    # Model pull service — pull + configure + Layer-1b probe
    # ---------------------------------------------------------------------------
    systemd.services."ollama-pull-models" = lib.mkIf (cfg.models != {}) {
      description = "Pull and configure Ollama models";
      after    = [ "${cfg.backend}-ollama.service" ];
      requires = [ "${cfg.backend}-ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        # Restart/RestartSec removed — ignored for Type=oneshot.
        # Retry logic is handled by the waitCmd polling loop in the script.

        # Layer 1b: after all pulls complete, warn about any model not yet
        # visible in /api/tags.  Uses WARN (not exit 1) because the model index
        # can lag a few seconds after 'ollama create'.
        ExecStartPost =
          "${pkgs.writeShellScript "ollama-model-probe" ''
            echo "[model probe] checking pulled models..."
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: _: ''
              if ${pkgs.curl}/bin/curl -sf \
                  http://127.0.0.1:${toString cfg.port}/api/tags \
                | ${pkgs.gnugrep}/bin/grep -q ${lib.escapeShellArg tag}; then
                echo "[model probe] OK: ${tag}"
              else
                echo "[model probe] WARN: ${tag} not yet listed in /api/tags" >&2
              fi
            '') cfg.models)}
          ''}";
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
    # MCP streamableHttp service + Layer-1c probe
    # ---------------------------------------------------------------------------
    systemd.services."ollama-mcp-server" = lib.mkIf cfg.mcp.enable {
      description = "Ollama MCP server (supergateway → ollama-mcp-server) for Cline";

      after    = [ "${cfg.backend}-ollama.service" ]
                 ++ lib.optional (cfg.models != {}) "ollama-pull-models.service";
      requires = [ "${cfg.backend}-ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.nodejs_22 pkgs.curl ];

      environment = {
        # ollama-mcp-server reads both env vars depending on version.
        # Always point at the host-side port mapping, not cfg.host (container bind addr).
        OLLAMA_HOST     = ollamaHostUrl;
        OLLAMA_BASE_URL = ollamaHostUrl;
      };

      serviceConfig = {
        Type       = "simple";
        Restart    = "always";
        RestartSec = "5s";

        ExecStart = lib.concatStringsSep " " [
          "${ollamaMcpWrapper}/bin/supergateway"
          "--port"            (toString cfg.mcp.port)
          "--host"            "0.0.0.0"
          "--cors"            "*"
          "--logLevel"        cfg.mcp.logLevel
          "--outputTransport" "streamableHttp"
          "--stdio"           (lib.escapeShellArg "${pkgs.nodejs_22}/bin/node ${ollamaMcpServerBin}")
        ];

        # Layer 1c: verify the MCP endpoint is answering before marking active.
        # supergateway returns 405 to bare GET /mcp (expects JSON-RPC POST),
        # so we treat both 200 and 405 as "port is live".
        ExecStartPost =
          "${pkgs.writeShellScript "ollama-mcp-probe" ''
            echo "[mcp probe] waiting for MCP endpoint on port ${toString cfg.mcp.port}..."
            for i in $(${pkgs.coreutils}/bin/seq 1 15); do
              code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" \
                http://127.0.0.1:${toString cfg.mcp.port}/mcp 2>/dev/null || echo "000")
              if [ "$code" = "200" ] || [ "$code" = "405" ]; then
                echo "[mcp probe] MCP endpoint alive (HTTP $code, attempt $i)"
                exit 0
              fi
              sleep 1
            done
            echo "[mcp probe] FAIL: MCP endpoint unresponsive after 15s" >&2
            exit 1
          ''}";

        NoNewPrivileges = true;
        PrivateTmp      = true;
        ProtectSystem   = "strict";
        ProtectHome     = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };

    # ---------------------------------------------------------------------------
    # Layer 2: on-demand smoke test
    # Trigger manually: systemctl start ollama-smoke-test
    # ---------------------------------------------------------------------------
    systemd.services."ollama-smoke-test" = lib.mkIf cfg.tests.enable {
      description = "Ollama smoke test (on-demand)";

      # Does not start automatically — no wantedBy.
      after    = [ "${cfg.backend}-ollama.service" ]
                 ++ lib.optional (cfg.models != {}) "ollama-pull-models.service"
                 ++ lib.optional cfg.mcp.enable    "ollama-mcp-server.service";
      requires = [ "${cfg.backend}-ollama.service" ];

      serviceConfig = {
        Type            = "oneshot";
        # RemainAfterExit = false (default) so re-running systemctl start
        # always executes the script fresh.
      };

      script =
        let
          # Model selection for the generate roundtrip:
          # explicit override > opencode_default > aider_default > first model.
          defaultModel =
            if cfg.tests.generateModel != "" then cfg.tests.generateModel
            else
              let
                oc  = lib.filter (t: cfg.models.${t}.opencode_default) (lib.attrNames cfg.models);
                ai  = lib.filter (t: cfg.models.${t}.aider_default)    (lib.attrNames cfg.models);
                all = lib.attrNames cfg.models;
              in
              if oc  != [] then lib.head oc
              else if ai  != [] then lib.head ai
              else if all != [] then lib.head all
              else "";

          generateTest = lib.optionalString (defaultModel != "") ''
            echo ""
            echo "=== [3] generate roundtrip (${defaultModel}) ==="
            response=$(${pkgs.curl}/bin/curl -sf \
              -X POST http://127.0.0.1:${toString cfg.port}/api/generate \
              -H 'Content-Type: application/json' \
              -d '{"model":${lib.escapeShellArg (builtins.toJSON defaultModel)},"prompt":"Reply with exactly one word: ok","stream":false}' \
              --max-time 60 2>&1)
            if echo "$response" | ${pkgs.gnugrep}/bin/grep -qi '"response"'; then
              echo "PASS: got a response field"
            else
              echo "FAIL: no response field in generate output" >&2
              echo "      raw: $response" >&2
              FAILED=1
            fi
          '';

          mcpTest = lib.optionalString cfg.mcp.enable ''
            echo ""
            echo "=== [4] MCP endpoint ==="
            code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" \
              http://127.0.0.1:${toString cfg.mcp.port}/mcp --max-time 5 2>/dev/null || echo "000")
            if [ "$code" = "200" ] || [ "$code" = "405" ]; then
              echo "PASS: MCP port ${toString cfg.mcp.port} alive (HTTP $code)"
            else
              echo "FAIL: MCP port ${toString cfg.mcp.port} returned HTTP $code" >&2
              FAILED=1
            fi
          '';

          modelListChecks = lib.optionalString (cfg.models != {}) ''
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: _: ''
              if echo "$tags" | ${pkgs.gnugrep}/bin/grep -q ${lib.escapeShellArg tag}; then
                echo "  PASS model listed: ${tag}"
              else
                echo "  WARN model not yet listed: ${tag}" >&2
              fi
            '') cfg.models)}
          '';
        in
        ''
          FAILED=0

          echo "=== [1] API reachability ==="
          if ${pkgs.curl}/bin/curl -sf \
              http://127.0.0.1:${toString cfg.port}/api/tags > /dev/null; then
            echo "PASS: /api/tags reachable"
          else
            echo "FAIL: /api/tags unreachable" >&2
            FAILED=1
          fi

          echo ""
          echo "=== [2] model listing ==="
          tags=$(${pkgs.curl}/bin/curl -sf \
            http://127.0.0.1:${toString cfg.port}/api/tags 2>/dev/null)
          if [ -z "$tags" ]; then
            echo "FAIL: empty response from /api/tags" >&2
            FAILED=1
          else
            echo "PASS: /api/tags returned data"
            ${modelListChecks}
          fi

          ${generateTest}
          ${mcpTest}

          echo ""
          if [ "$FAILED" = "0" ]; then
            echo "=== ALL TESTS PASSED ==="
          else
            echo "=== SOME TESTS FAILED — check output above ===" >&2
            exit 1
          fi
        '';
    };

    # ---------------------------------------------------------------------------
    # Layer 3: interactive CLI wrapper
    # Usage: ollama-test   (requires sudo for systemctl start)
    # ---------------------------------------------------------------------------
    environment.systemPackages = lib.mkIf cfg.tests.enable [
      (pkgs.writeShellScriptBin "ollama-test" ''
        echo "Running Ollama smoke test..."
        sudo ${pkgs.systemd}/bin/systemctl start ollama-smoke-test
        echo ""
        echo "--- journal output ---"
        ${pkgs.systemd}/bin/journalctl -u ollama-smoke-test -n 60 --no-pager
      '')
    ];

    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.mcp.enable && cfg.mcp.openFirewall) [ cfg.mcp.port ];
  };
}
