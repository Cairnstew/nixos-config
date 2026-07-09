{ config, lib, pkgs, ... }:
{
  options.my.services.open-webui = {
    enable = lib.mkEnableOption "Open WebUI OCI container service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/open-webui/open-webui:main";
      description = "OCI image for Open WebUI.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Host port to expose the Open WebUI on.";
    };

    containerPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal container port (8080 for main image).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/open-webui";
      description = "Host path to persist Open WebUI data (database, uploads).";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    ollama = {
      enable = lib.mkEnableOption "connect to local Ollama instance";
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://ollama:11434";
        description = "Ollama API base URL. Default uses the ollama network alias.";
      };
    };

    webSearch = {
      enable = lib.mkEnableOption "web search for RAG";
      provider = lib.mkOption {
        type = lib.types.enum [ "duckduckgo" "searxng" "google" "brave" "bing" "kagi" "tavily" "perplexity" "serpapi" "jina" ];
        default = "duckduckgo";
        description = "Web search provider.";
      };
      searxngBaseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Base URL for SearXNG (required when provider = searxng).";
      };
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "API key for the web search provider (if required).";
      };
    };

    rag = {
      embeddingModel = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Embedding model for RAG (defaults to Ollama embedding).";
      };
      topK = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Number of RAG results to inject.";
      };
    };

    trustedProxies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Trusted proxy IPs/CIDRs (for reverse proxy setups).";
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
        default = "open-webui-net";
      };
      alias = lib.mkOption {
        type = lib.types.str;
        default = "open-webui";
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
