{ config, lib, pkgs, ... }:
{
  options.my.services.jan = {
    enable = lib.mkEnableOption "Jan desktop app and API server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jan;
      defaultText = lib.literalExpression "pkgs.jan";
      description = "Jan package to use.";
    };

    apiServer = {
      enable = lib.mkEnableOption "Jan API server (OpenAI-compatible at localhost:1337)";
      port = lib.mkOption {
        type = lib.types.port;
        default = 1337;
        description = "Port for the Jan API server.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Listen address for the API server.";
      };
    };

    ollama = {
      enable = lib.mkEnableOption "auto-configure Ollama as a model source in Jan";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
        description = "Ollama API base URL.";
      };
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jan";
      description = "Host path for Jan data (models, threads, settings).";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Jan settings written to settings.json.";
    };
  };
}
