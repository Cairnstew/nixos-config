{ flake, pkgs, lib, ... }:
let
  me   = flake.config.me;
  user = me.username;
  nm   = flake.inputs.self.nixosModules;

  ollamaModels    = flake.config.ollamaModels;
  sillytavernModel = "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrixlatest";
in
{
  imports = [
    "${flake.inputs.nixos-vscode-server}/modules/vscode-server/default.nix"
    nm.default
  ];

  services.vscode-server.enable = true;

  my.services = {
    ollama = {
      enable     = true;
      backend = "docker";
      port = 11434;
      gpu = {
        enable = true;
        type = "nvidia";
        nvidiaDeviceArg = "all";
        healthCheck = true;
      };
      mcp = {
        enable       = true;
        listenAddress = "0.0.0.0";  # accept remote connections
        openFirewall  = true;
      };
      models  = ollamaModels;
      host       = "0.0.0.0";
      performance = {
        numParallel      = 1;
        maxLoadedModels  = 1;
        maxVram          = 10000000000; # leave ~2GB free, spill rest to RAM
        flashAttention   = true;        # reduces VRAM for large contexts
      };
    };

    sillytavern = {
      enable             = true;
      port               = 8111;
      listen             = true;
      whitelistMode      = true;
      whitelistAddresses = map (h: h.ip) (lib.attrValues flake.config.tailnet);

      ollama = {
        enable = true;
        host   = "127.0.0.1";
        port   = 11434;
        model  = sillytavernModel;
      };

      presets = {
        instruct  = { };
        sysprompt = { };

        context."hf.coLewdiculousDS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrixlatest" = {
          story_string       = "{{#if anchorBefore}}{{anchorBefore}}\n{{/if}}{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{personality}}\n{{/if}}{{#if scenario}}{{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}{{#if anchorAfter}}{{anchorAfter}}\n{{/if}}{{trim}}";
          always_force_name2 = false;
        };

        textgen = {
          "Default"  = { };
          "Creative" = {
            temp    = 1.1;
            top_p   = 0.95;
            min_p   = 0.05;
            rep_pen = 1.05;
            genamt  = 2048;
          };
        };
      };
    };
  };
}