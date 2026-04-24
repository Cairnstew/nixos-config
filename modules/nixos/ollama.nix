{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.ollama;

  packageMap = {
    cuda   = pkgs.ollama-cuda;
    rocm   = pkgs.ollama-rocm;
    vulkan = pkgs.ollama-vulkan;
    null   = pkgs.ollama;
  };
in
{
  options.my.services.ollama = {
    enable = lib.mkEnableOption "Ollama inference server";

    acceleration = lib.mkOption {
      type    = lib.types.nullOr (lib.types.enum [ "cuda" "rocm" "vulkan" ]);
      default = null;
      description = "Hardware acceleration backend. null = CPU only.";
    };

    loadModels = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "llama3.2" "mistral" ];
      description = "Models to pull automatically on service start.";
    };

    models = lib.mkOption {
      type    = lib.types.nullOr lib.types.str;
      default = null;
      example = "/mnt/storage/ollama/models";
      description = ''
        Directory to store downloaded models. Defaults to
        services.ollama.home/models (/var/lib/ollama/models) when null.
      '';
    };

    port = lib.mkOption {
      type    = lib.types.port;
      default = 11434;
      description = "Port Ollama listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = lib.mkIf (cfg.models != null) [
      "d ${cfg.models} 0755 ollama ollama -"
    ];

    services.ollama = {
      enable     = true;
      user       = "ollama";   # needed so tmpfiles ownership matches
      group      = "ollama";
      port       = cfg.port;
      loadModels = cfg.loadModels;
      package    = packageMap.${if cfg.acceleration == null then "null" else cfg.acceleration};
    } // lib.optionalAttrs (cfg.models != null) {
      models = cfg.models;
    };
  };
}