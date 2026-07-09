{ config, lib, pkgs, ... }:
{
  options.my.services.risuai = {
    enable = lib.mkEnableOption "RisuAI OCI container service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/kwaroran/risuai:latest";
      description = "OCI image for RisuAI.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6001;
      description = "Host port to expose the RisuAI web UI on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/risuai";
      description = "Host path to persist RisuAI data (characters, chats, lorebooks).";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    ollama = {
      enable = lib.mkEnableOption "auto-configure Ollama as the default API endpoint";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://ollama:11434";
        description = "Ollama API base URL from inside the container. Default uses the ollama network alias.";
      };
    };

    openaiCompat = {
      apiBaseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "http://host.docker.internal:11434/v1";
        description = "OpenAI-compatible API base URL (e.g. Ollama or any OpenAI proxy).";
      };
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "API key for the OpenAI-compatible endpoint.";
      };
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Listen address inside the container.";
    };

    extraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra volume mounts for the container.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the container.";
    };

    logDriver = lib.mkOption {
      type = lib.types.str;
      default = "journald";
      description = "Logging driver for the container.";
    };

    autoPrune = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic Docker system pruning.";
    };

    network = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "risuai-net";
        description = "Docker network name.";
      };
      alias = lib.mkOption {
        type = lib.types.str;
        default = "risuai";
        description = "Container network alias.";
      };
    };

    restart = {
      policy = lib.mkOption { type = lib.types.str; default = "always"; };
      maxDelaySec = lib.mkOption { type = lib.types.str; default = "1m"; };
      delaySec = lib.mkOption { type = lib.types.str; default = "100ms"; };
      steps = lib.mkOption { type = lib.types.int; default = 9; };
    };
  };
}
