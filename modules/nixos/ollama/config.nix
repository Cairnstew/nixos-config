{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.ollama;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length (lib.filter (tag: cfg.models.${tag}.opencode_default) (lib.attrNames cfg.models)) <= 1;
        message = "my.services.ollama.models: only one model may have opencode_default = true";
      }
      {
        assertion = lib.length (lib.filter (tag: cfg.models.${tag}.cline_default) (lib.attrNames cfg.models)) <= 1;
        message = "my.services.ollama.models: only one model may have cline_default = true";
      }
      {
        assertion = lib.length (lib.filter (tag: cfg.models.${tag}.aider_default) (lib.attrNames cfg.models)) <= 1;
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
        OLLAMA_HOST = cfg.host;
        OLLAMA_NUM_PARALLEL = lib.optionalString (cfg.performance.numParallel != null) (toString cfg.performance.numParallel);
        OLLAMA_MAX_LOADED_MODELS = lib.optionalString (cfg.performance.maxLoadedModels != null) (toString cfg.performance.maxLoadedModels);
        OLLAMA_MAX_VRAM = lib.optionalString (cfg.performance.maxVram != null) (toString cfg.performance.maxVram);
        OLLAMA_FLASH_ATTENTION = if cfg.performance.flashAttention then "1" else "";
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
          else if cfg.gpu.type == "amd" then [ "--device=/dev/kfd" "--device=/dev/dri" ]
          else if cfg.gpu.type == "intel" then [ "--device=/dev/dri" ]
          else [ ]
        ))
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
        cfg.extraOptions
      ];
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.mcp.enable && cfg.mcp.openFirewall) [ cfg.mcp.port ];
  };
}
