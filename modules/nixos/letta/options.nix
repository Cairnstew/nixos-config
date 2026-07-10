{ config, lib, pkgs, ... }:
{
  options.my.services.letta = {
    enable = lib.mkEnableOption "Letta OCI container service (stateful AI agents with persistent memory)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "letta/letta:0.16.8";
      description = "OCI image for the Letta API server.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8283;
      description = "Host port to expose the Letta API on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/letta";
      description = "Host path to persist Letta data (agent memories, config).";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite" "postgres" ];
        default = "sqlite";
        description = "Database backend for agent state storage.";
      };
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Full database URL. For postgres: postgres://user:pass@host:5432/letta
          If null, uses a local SQLite file in dataDir.
        '';
      };
    };

    ollama = {
      enable = lib.mkEnableOption "use Ollama as the LLM backend";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://ollama:11434";
        description = "Ollama API base URL.";
      };
      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "llama3.2:3b";
        description = "Default model tag to use for agents.";
      };
    };

    openaiCompat = {
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "API key for OpenAI-compatible endpoint.";
      };
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
    };

    autoPrune = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    network = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "letta-net";
      };
      alias = lib.mkOption {
        type = lib.types.str;
        default = "letta";
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
