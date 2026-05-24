{ config, lib, pkgs, ... }:
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
      description = "IP address Ollama listens on inside the container (sets OLLAMA_HOST).";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        freeformType = with lib.types; attrsOf anything;
        options = {
          name = lib.mkOption { type = lib.types.str; description = "Display name."; };
          tools = lib.mkOption { type = lib.types.bool; default = false; description = "Model supports tool/function calling."; };
          opencode_default = lib.mkOption { type = lib.types.bool; default = false; description = "Use as default model in opencode."; };
          aider_default = lib.mkOption { type = lib.types.bool; default = false; description = "Use as default model in aider."; };
          cline_default = lib.mkOption { type = lib.types.bool; default = false; description = "Use as default model in Cline."; };
          numCtx = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; description = "Context window size (num_ctx)."; };
          temperature = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; description = "Sampling temperature."; };
          think = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; description = "Enable chain-of-thought reasoning."; };
          topK = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
          topP = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          repeatPenalty = lib.mkOption { type = lib.types.nullOr lib.types.float; default = null; };
          numPredict = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
          seed = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
          systemPrompt = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          template = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
        };
      });
      default = { };
      description = "Attrset of models to pull and configure after the container starts.";
    };

    gpu = {
      enable = lib.mkEnableOption "GPU passthrough for the Ollama container";
      type = lib.mkOption { type = lib.types.enum [ "nvidia" "amd" "intel" ]; default = "nvidia"; };
      nvidiaDeviceArg = lib.mkOption { type = lib.types.str; default = "all"; };
      healthCheck = lib.mkOption { type = lib.types.bool; default = true; };
    };

    network = {
      name = lib.mkOption { type = lib.types.str; default = "ollama-net"; };
      alias = lib.mkOption { type = lib.types.str; default = "ollama"; };
    };

    extraVolumes = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    extraOptions = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    environmentVariables = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = { }; };
    logDriver = lib.mkOption { type = lib.types.str; default = "journald"; };
    autoPrune = lib.mkOption { type = lib.types.bool; default = true; };

    restart = {
      policy = lib.mkOption { type = lib.types.str; default = "always"; };
      maxDelaySec = lib.mkOption { type = lib.types.str; default = "1m"; };
      delaySec = lib.mkOption { type = lib.types.str; default = "100ms"; };
      steps = lib.mkOption { type = lib.types.int; default = 9; };
    };

    performance = {
      numParallel = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 1; };
      maxLoadedModels = lib.mkOption { type = lib.types.nullOr lib.types.int; default = 1; };
      maxVram = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
      flashAttention = lib.mkOption { type = lib.types.bool; default = false; };
    };

    mcp = {
      enable = lib.mkEnableOption "Ollama MCP server for Cline (supergateway + ollama-mcp-server)";
      port = lib.mkOption { type = lib.types.port; default = 3100; };
      openFirewall = lib.mkOption { type = lib.types.bool; default = false; };
      logLevel = lib.mkOption { type = lib.types.enum [ "debug" "info" "none" ]; default = "info"; };
    };

    tests = {
      enable = lib.mkEnableOption "Ollama smoke-test suite (ollama-smoke-test oneshot + ollama-test CLI)";
      generateModel = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Model tag to use for the generate roundtrip in the smoke test.";
      };
    };
  };
}
