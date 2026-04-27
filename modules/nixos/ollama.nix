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

    models = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = ''
        Attrset of models to pull and configure after the container starts.
        The attrset key is the model tag passed to "ollama pull".
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
  };

  config = lib.mkIf cfg.enable {

    virtualisation.docker = lib.mkIf (cfg.backend == "docker") {
      enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault cfg.autoPrune;
    };

    virtualisation.podman = lib.mkIf (cfg.backend == "podman") {
      enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault cfg.autoPrune;
    };

    # Ensure the data directory exists before the container starts.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    virtualisation.oci-containers.backend = cfg.backend;

    virtualisation.oci-containers.containers."ollama" = {
      image = cfg.image;

      volumes = [ "${cfg.dataDir}:/root/.ollama:rw" ] ++ cfg.extraVolumes;

      ports = [ "${toString cfg.port}:11434/tcp" ];

      environment = { OLLAMA_HOST = cfg.host; } // cfg.environmentVariables;

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

    systemd.services."${cfg.backend}-ollama" = {
      serviceConfig = {
        Restart            = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec         = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps       = lib.mkOverride 90 cfg.restart.steps;
        # Create the container network before the container starts.
        ExecStartPre       = lib.mkOverride 90
          "${pkgs.writeShellScript "ollama-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";
      };
      partOf   = [ "${cfg.backend}-compose-ollama-root.target" ];
      wantedBy = [ "${cfg.backend}-compose-ollama-root.target" ];
    };

    # Oneshot service that pulls and configures every model in cfg.models.
    # Runs on every boot so numCtx and other Modelfile settings are always applied,
    # even for models that were previously pulled without them.
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
            echo "Waiting for Ollama API on port ${toString cfg.port}..."
            until ${pkgs.curl}/bin/curl -sf "http://127.0.0.1:${toString cfg.port}/api/tags" > /dev/null 2>&1; do
              sleep 2
            done
            echo "Ollama API is up."
          '';
          modelCmds = lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: mcfg:
            let
              safeName = builtins.replaceStrings [ ":" "/" ] [ "-" "-" ] tag;
              hasModelfile = (mcfg.numCtx or null) != null || (mcfg.temperature or null) != null;
            in
            ''
              echo "Pulling model: ${tag}"
              ${backendBin} exec ollama ollama pull ${lib.escapeShellArg tag}
            '' + lib.optionalString hasModelfile ''
              echo "Applying Modelfile for ${tag}..."
              MODELFILE=$(mktemp)
              printf 'FROM ${tag}\n' > "$MODELFILE"
            '' + lib.optionalString ((mcfg.numCtx or null) != null) ''
              printf 'PARAMETER num_ctx ${toString mcfg.numCtx}\n' >> "$MODELFILE"
            '' + lib.optionalString ((mcfg.temperature or null) != null) ''
              printf 'PARAMETER temperature ${toString mcfg.temperature}\n' >> "$MODELFILE"
            '' + lib.optionalString hasModelfile ''
              ${backendBin} cp "$MODELFILE" ollama:/tmp/Modelfile.${safeName}
              ${backendBin} exec ollama ollama create ${lib.escapeShellArg safeName} -f /tmp/Modelfile.${safeName}
              rm -f "$MODELFILE"
            ''
          ) cfg.models);
        in
          waitCmd + "\n" + modelCmds;
    };

    systemd.targets."${cfg.backend}-compose-ollama-root" = {
      unitConfig.Description = "Ollama OCI container root target.";
      wantedBy = [ "multi-user.target" ];
    };
  };
}
