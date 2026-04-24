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

    host = lib.mkOption {
      type    = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        The host address Ollama listens on.
        Use 0.0.0.0 to listen on all interfaces,
        or a specific IP (e.g. Tailscale) to restrict access.
      '';
    };

    port = lib.mkOption {
      type    = lib.types.port;
      default = 11434;
      description = "Port Ollama listens on.";
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
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = lib.mkIf (cfg.models != null) [
      "d ${cfg.models} 0755 ollama ollama -"
    ];

    services.ollama = {
      enable     = true;
      user       = "ollama";
      group      = "ollama";
      host       = cfg.host;
      port       = cfg.port;
      loadModels = cfg.loadModels;
      package    = packageMap.${if cfg.acceleration == null then "null" else cfg.acceleration};
    } // lib.optionalAttrs (cfg.models != null) {
      models = cfg.models;
    };
  };
}