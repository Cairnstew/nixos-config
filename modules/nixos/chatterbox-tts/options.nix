{ lib, ... }:
{
  options.my.services.chatterbox-tts = {
    enable = lib.mkEnableOption "Chatterbox TTS server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Chatterbox TTS server package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "chatterbox-tts";
      description = "User account under which the server runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "chatterbox-tts";
      description = "Group account under which the server runs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8004;
      description = "Port on which the TTS server will listen.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "100.x.x.x";
      description = "IP address to bind to. Use 127.0.0.1 for localhost-only, or a Tailscale IP for tailnet access.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured port in the firewall.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "cpu" "cuda" "rocm" ];
      default = "cpu";
      description = "Compute backend for TTS inference. CPU is recommended alongside Ollama to avoid VRAM contention.";
    };

    model = lib.mkOption {
      type = lib.types.enum [ "chatterbox" "chatterbox-turbo" "chatterbox-multilingual" ];
      default = "chatterbox-turbo";
      description = "TTS model to load. chatterbox-turbo (350M params) is fastest on CPU with paralinguistic tag support.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/chatterbox-tts";
      description = "Persistent state directory for model cache, config, voices, and outputs.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = {
        generation_defaults = {
          temperature = 0.9;
          exaggeration = 1.0;
        };
        audio_output = {
          format = "mp3";
          sample_rate = 24000;
        };
      };
      description = "Extra configuration values merged into config.yaml on service start. Overrides module defaults.";
    };
  };
}
