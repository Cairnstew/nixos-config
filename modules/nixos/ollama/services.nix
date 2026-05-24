{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.ollama;
  backendBin = if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";

  ollamaMcpWrapper = pkgs.buildNpmPackage {
    pname = "ollama-mcp-wrapper";
    version = "1.0.0";
    nodejs = pkgs.nodejs_22;
    src = pkgs.runCommand "ollama-mcp-wrapper-src" { } ''
      mkdir -p $out
      cp ${pkgs.writeText "package.json" (builtins.toJSON {
        name = "ollama-mcp-wrapper";
        version = "1.0.0";
        dependencies = {
          "ollama-mcp-server" = "1.1.0";
          "supergateway" = "3.4.3";
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

  ollamaHostUrl = "http://127.0.0.1:${toString cfg.port}";
in
{
  config = lib.mkIf cfg.enable {
    systemd.services."${cfg.backend}-ollama" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps = lib.mkOverride 90 cfg.restart.steps;

        ExecStartPre = lib.mkOverride 90
          "${pkgs.writeShellScript "ollama-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";

        ExecStartPost = lib.mkOverride 90
          "${pkgs.writeShellScript "ollama-container-probe" ''
            echo "[ollama probe] waiting for API..."
            for i in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/api/tags > /dev/null 2>&1; then
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

    systemd.services."ollama-pull-models" = lib.mkIf (cfg.models != { }) {
      description = "Pull and configure Ollama models";
      after = [ "${cfg.backend}-ollama.service" ];
      requires = [ "${cfg.backend}-ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPost =
          "${pkgs.writeShellScript "ollama-model-probe" ''
            echo "[model probe] checking pulled models..."
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: _: ''
              if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/api/tags \
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
            (lib.optionalString (mcfg.numCtx != null) "printf 'PARAMETER num_ctx %s\\n' '${toString mcfg.numCtx}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.temperature != null) "printf 'PARAMETER temperature %s\\n' '${toString mcfg.temperature}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.topK != null) "printf 'PARAMETER top_k %s\\n' '${toString mcfg.topK}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.topP != null) "printf 'PARAMETER top_p %s\\n' '${toString mcfg.topP}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.repeatPenalty != null) "printf 'PARAMETER repeat_penalty %s\\n' '${toString mcfg.repeatPenalty}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.numPredict != null) "printf 'PARAMETER num_predict %s\\n' '${toString mcfg.numPredict}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.seed != null) "printf 'PARAMETER seed %s\\n' '${toString mcfg.seed}' >> \"$MODELFILE\"\n")
            (lib.optionalString (mcfg.think != null) "printf 'PARAMETER think %s\\n' '${if mcfg.think == true then "true" else "false"}' >> \"$MODELFILE\"\n")
          ]);

          hasModelfile = mcfg:
            mcfg.numCtx != null || mcfg.temperature != null || mcfg.topK != null ||
            mcfg.topP != null || mcfg.repeatPenalty != null || mcfg.numPredict != null ||
            mcfg.seed != null || mcfg.think != null || mcfg.systemPrompt != null || mcfg.template != null;

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

    systemd.services."ollama-mcp-server" = lib.mkIf cfg.mcp.enable {
      description = "Ollama MCP server (supergateway → ollama-mcp-server) for Cline";
      after = [ "${cfg.backend}-ollama.service" ]
        ++ lib.optional (cfg.models != { }) "ollama-pull-models.service";
      requires = [ "${cfg.backend}-ollama.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.nodejs_22 pkgs.curl ];

      environment = {
        OLLAMA_HOST = ollamaHostUrl;
        OLLAMA_BASE_URL = ollamaHostUrl;
      };

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = lib.concatStringsSep " " [
          "${ollamaMcpWrapper}/bin/supergateway"
          "--port" (toString cfg.mcp.port)
          "--host" "0.0.0.0"
          "--cors" "*"
          "--logLevel" cfg.mcp.logLevel
          "--outputTransport" "streamableHttp"
          "--stdio" (lib.escapeShellArg "${pkgs.nodejs_22}/bin/node ${ollamaMcpServerBin}")
        ];
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
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };

    systemd.services."ollama-smoke-test" = lib.mkIf cfg.tests.enable {
      description = "Ollama smoke test (on-demand)";
      after = [ "${cfg.backend}-ollama.service" ]
        ++ lib.optional (cfg.models != { }) "ollama-pull-models.service"
        ++ lib.optional cfg.mcp.enable "ollama-mcp-server.service";
      requires = [ "${cfg.backend}-ollama.service" ];
      serviceConfig.Type = "oneshot";
      script =
        let
          defaultModel =
            if cfg.tests.generateModel != "" then cfg.tests.generateModel
            else
              let
                oc = lib.filter (t: cfg.models.${t}.opencode_default) (lib.attrNames cfg.models);
                ai = lib.filter (t: cfg.models.${t}.aider_default) (lib.attrNames cfg.models);
                all = lib.attrNames cfg.models;
              in
              if oc != [ ] then lib.head oc
              else if ai != [ ] then lib.head ai
              else if all != [ ] then lib.head all
              else "";

          generateTest = lib.optionalString (defaultModel != "") ''
            echo ""
            echo "=== [3] generate roundtrip (${defaultModel}) ==="
            response=$(${pkgs.curl}/bin/curl -sf \
              -X POST http://127.0.0.1:${toString cfg.port}/api/generate \
              -H 'Content-Type: application/json' \
              -d ${lib.escapeShellArg (builtins.toJSON { model = defaultModel; prompt = "Reply with exactly one word: ok"; stream = false; })} \
              --max-time 360 2>&1)
            if echo "$response" | ${pkgs.gnugrep}/bin/grep -qi '"response"'; then
              echo "PASS: got a response field"
            else
              echo "FAIL: no response field in generate output" >&2
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

          modelListChecks = lib.optionalString (cfg.models != { }) ''
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
          if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/api/tags > /dev/null; then
            echo "PASS: /api/tags reachable"
          else
            echo "FAIL: /api/tags unreachable" >&2
            FAILED=1
          fi
          echo ""
          echo "=== [2] model listing ==="
          tags=$(${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/api/tags 2>/dev/null)
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

    environment.systemPackages = lib.mkIf cfg.tests.enable [
      (pkgs.writeShellScriptBin "ollama-test" ''
        echo "Running Ollama smoke test..."
        sudo ${pkgs.systemd}/bin/systemctl start ollama-smoke-test
        echo ""
        echo "--- journal output ---"
        ${pkgs.systemd}/bin/journalctl -u ollama-smoke-test -n 60 --no-pager
      '')
    ];
  };
}
