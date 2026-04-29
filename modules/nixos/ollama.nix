{ config, pkgs, lib, ... }:

let
  cfg = config.my.services.ollama;
  backendBin = if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";
in
{
  options.my.services.ollama = {
    enable = lib.mkEnableOption "Ollama OCI container service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ollama/ollama:latest";
      description = "Docker image to use for the Ollama container.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ollama";
      description = "Host path to persist Ollama model data.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Host port to expose the Ollama API on.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        IP address Ollama listens on inside the container (sets OLLAMA_HOST).
        Use "0.0.0.0" to accept connections from outside the host.
      '';
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    # ---------------------------------------------------------------------------
    # Per-model submodule
    # FIX 1: topK / topP / repeatPenalty / seed / systemPrompt / template moved
    #         here from performance so they can be set independently per model.
    # ---------------------------------------------------------------------------
    models = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {

        freeformType = with lib.types; attrsOf anything;
        
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable display name for the model.";
          };

          tools = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether this model supports tool/function calling (informational only).";
          };
          
          opencode_default = lib.mkOption {
            type    = lib.types.bool;
            default = false;
            description = "Mark this model as the default for opencode. Only one model should have this set.";
          };

          numCtx = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            example = 32768;
            description = ''
              Context window size to apply via a Modelfile. If set, creates a
              custom model named "<key>-custom" with the specified num_ctx.
              Applied on every boot so changes take effect automatically.
            '';
          };

          temperature = lib.mkOption {
            type = lib.types.nullOr lib.types.float;
            default = null;
            example = 0.1;
            description = ''
              Sampling temperature. Lower values (0.1–0.3) are more deterministic
              and better for tool calling. Applied via Modelfile on every boot.
            '';
          };

          think = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            example = false;
            description = ''
              Enable or disable Qwen3 thinking mode via Modelfile.
              Set to false for more reliable tool calling.
            '';
          };

          # --- sampling params (were incorrectly under performance) ---

          topK = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            example = 40;
            description = "Top-K sampling. Reduces probability of generating nonsense.";
          };

          topP = lib.mkOption {
            type = lib.types.nullOr lib.types.float;
            default = null;
            example = 0.9;
            description = "Top-P (nucleus) sampling.";
          };

          repeatPenalty = lib.mkOption {
            type = lib.types.nullOr lib.types.float;
            default = null;
            example = 1.1;
            description = "Penalises repeated tokens.";
          };

          numPredict = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            example = 2048;
            description = ''
              Maximum number of tokens to generate in a response (PARAMETER num_predict).
              -1 = infinite, -2 = fill context window. Defaults to 128 if unset.
            '';
          };

          seed = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            example = 42;
            description = "RNG seed. Set for reproducible outputs.";
          };

          systemPrompt = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "SYSTEM prompt baked into the Modelfile.";
          };

          template = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Raw Ollama TEMPLATE string. Overrides the model's built-in chat template.
              Use Go template syntax as per Ollama docs.
            '';
          };
        };
      });
      default = {};
      example = {
        "llama3:8b" = { name = "Llama 3 8B"; tools = false; numCtx = 8192; };
        "qwen3:8b"  = { name = "Qwen 3 8B";  tools = true;  numCtx = 32768; think = false; temperature = 0.1; };
      };
      description = ''
        Attrset of models to pull and configure after the container starts.
        The attrset key is the model tag passed to "ollama pull".
        Models with any Modelfile option set will have a custom Modelfile applied
        on every boot, even if the model was previously pulled without it.
        The created model will be named after the tag with ":" and "/" replaced by "-".
      '';
    };

    gpu = {
      enable = lib.mkEnableOption "GPU passthrough for the Ollama container";

      type = lib.mkOption {
        type = lib.types.enum [ "nvidia" "amd" "intel" ];
        default = "nvidia";
        description = "GPU vendor type to pass through to the container.";
      };

      nvidiaDeviceArg = lib.mkOption {
        type = lib.types.str;
        default = "all";
        description = ''
          Value for the --device=nvidia.com/gpu= argument (e.g. "all", "0", "0,1").
          Only used when gpu.type is "nvidia".
        '';
      };

      healthCheck = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nvidia-smi health check. Only applies when gpu.type is nvidia.";
      };
    };

    network = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "ollama-net";
        description = "Docker/Podman network name for the Ollama container.";
      };

      alias = lib.mkOption {
        type = lib.types.str;
        default = "ollama";
        description = "Network alias for the Ollama container.";
      };
    };

    extraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "/mnt/models:/models:ro" ];
      description = "Additional volume mounts to pass to the container.";
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "--env=OLLAMA_DEBUG=1" ];
      description = "Additional arbitrary options to pass to the container runtime.";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = { OLLAMA_MODELS = "/root/.ollama/models"; };
      description = "Extra environment variables for the container. OLLAMA_HOST is set via the host option.";
    };

    logDriver = lib.mkOption {
      type = lib.types.str;
      default = "journald";
      description = "Logging driver for the container.";
    };

    restart = {
      policy = lib.mkOption {
        type = lib.types.str;
        default = "always";
        description = "Systemd service restart policy.";
      };

      maxDelaySec = lib.mkOption {
        type = lib.types.str;
        default = "1m";
        description = "Maximum delay between restarts.";
      };

      delaySec = lib.mkOption {
        type = lib.types.str;
        default = "100ms";
        description = "Initial delay between restarts.";
      };

      steps = lib.mkOption {
        type = lib.types.int;
        default = 9;
        description = "Number of restart steps for exponential backoff.";
      };
    };

    autoPrune = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic pruning of unused container resources.";
    };

    performance = {
      numParallel = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = 1;
        description = ''
          Maximum number of models to load in parallel (OLLAMA_NUM_PARALLEL).
          Set to 1 to prevent multiple models competing for VRAM/RAM.
        '';
      };

      maxLoadedModels = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = 1;
        description = ''
          Maximum number of models to keep loaded in memory (OLLAMA_MAX_LOADED_MODELS).
          Set to 1 to evict models aggressively and free memory between uses.
        '';
      };

      maxVram = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 10000000000;
        description = ''
          Maximum VRAM to use in bytes (OLLAMA_MAX_VRAM). Layers exceeding this
          will spill to system RAM. Leave null to let Ollama use all available VRAM.
          Example: 10000000000 reserves ~2GB free on a 12GB card.
        '';
      };

      flashAttention = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable flash attention (OLLAMA_FLASH_ATTENTION). Reduces VRAM usage
          for large context windows. Recommended when using large numCtx values.
        '';
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

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

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
          else if cfg.gpu.type == "amd" then [
            "--device=/dev/kfd"
            "--device=/dev/dri"
          ]
          else if cfg.gpu.type == "intel" then [
            "--device=/dev/dri"
          ]
          else []
        ))
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
        cfg.extraOptions
      ];
    };

    # FIX 2: Removed broken partOf/wantedBy pointing at a non-existent compose
    #         target. Plain oci-containers uses docker-ollama / podman-ollama
    #         directly. Network creation moved here as ExecStartPre.
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

    # ---------------------------------------------------------------------------
    # Model pull + Modelfile service
    # FIX 3: waitCmd replaced with a real readiness loop.
    # FIX 1: paramLines / hasModelfile now read per-model fields correctly.
    # ---------------------------------------------------------------------------
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
          # FIX 3: real wait loop — polls the REST API until Ollama is ready.
          waitCmd = ''
            echo "Waiting for Ollama to become ready..."
            until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/api/tags > /dev/null 2>&1; do
              echo "  ...not ready yet, retrying in 2s"
              sleep 2
            done
            echo "Ollama is ready."
          '';

          # FIX 1: mcfg is a per-model config — all fields now live on the model submodule.
          paramLines = mcfg: lib.concatStringsSep "" (
            lib.filter (s: s != "") [
              (lib.optionalString (mcfg.numCtx       != null) "printf 'PARAMETER num_ctx %s\\n'       '${toString mcfg.numCtx}'       >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.temperature  != null) "printf 'PARAMETER temperature %s\\n'   '${toString mcfg.temperature}'  >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.topK         != null) "printf 'PARAMETER top_k %s\\n'         '${toString mcfg.topK}'         >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.topP         != null) "printf 'PARAMETER top_p %s\\n'         '${toString mcfg.topP}'         >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.repeatPenalty != null) "printf 'PARAMETER repeat_penalty %s\\n' '${toString mcfg.repeatPenalty}' >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.numPredict != null) "printf 'PARAMETER num_predict %s\\n' '${toString mcfg.numPredict}' >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.seed         != null) "printf 'PARAMETER seed %s\\n'          '${toString mcfg.seed}'         >> \"$MODELFILE\"\n")
              (lib.optionalString (mcfg.think        != null) "printf 'PARAMETER think %s\\n'         '${if mcfg.think == true then "true" else "false"}' >> \"$MODELFILE\"\n")
            ]
          );

          hasModelfile = mcfg:
            mcfg.numCtx        != null ||
            mcfg.temperature   != null ||
            mcfg.topK          != null ||
            mcfg.topP          != null ||
            mcfg.repeatPenalty != null ||
            mcfg.numPredict != null ||
            mcfg.seed          != null ||
            mcfg.think         != null ||
            mcfg.systemPrompt  != null ||
            mcfg.template      != null;

          modelCmds = lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: mcfg:
            let
              # e.g. "qwen3:8b" -> "qwen3-8b"  used as the created model name
              safeName = builtins.replaceStrings [ ":" "/" ] [ "-" "-" ] tag;
            in
            ''
              echo "--- Pulling model: ${tag} ---"
              ${backendBin} exec ollama ollama pull ${lib.escapeShellArg tag}
            '' + lib.optionalString (hasModelfile mcfg) ''
              echo "Applying Modelfile for ${tag} (will be available as '${safeName}')..."
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
              echo "Model '${safeName}' created successfully."
            ''
          ) cfg.models);
        in
          waitCmd + "\n" + modelCmds;
    };
  };
}
