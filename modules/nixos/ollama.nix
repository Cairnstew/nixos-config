{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.ollama;
in
{
  options.my.services.ollama = {
    enable = lib.mkEnableOption "Custom Ollama Service";

    acceleration = lib.mkOption {
      type = lib.types.enum [ "cpu" "cuda" "rocm" "vulkan" ];
      default = "cpu";
      description = "Which hardware acceleration to use for Ollama.";
    };

    loadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "llama3.2" "mistral" ];
      description = "List of models to pull automatically when the service starts.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "The port Ollama should listen on.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      port = cfg.port;
      loadModels = cfg.loadModels;
      
      # Selects the specific package based on your acceleration choice
      package = {
        cpu = pkgs.ollama-cpu;
        cuda = pkgs.ollama-cuda;
        rocm = pkgs.ollama-rocm;
        vulkan = pkgs.ollama-vulkan;
      }.${cfg.acceleration};
    };
  };
}