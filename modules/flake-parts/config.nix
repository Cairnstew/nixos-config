# Top-level configuration for everything in this repo.
#
# Values are set in 'config.nix' in repo root.
{ lib, ... }:
let
  userSubmodule = lib.types.submodule {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
      };
      fullname = lib.mkOption {
        type = lib.types.str;
      };
      email = lib.mkOption {
        type = lib.types.str;
      };
      sshKey = lib.mkOption {
        type = lib.types.str;
        description = ''
          SSH public key
        '';
      };
      github_username = lib.mkOption {
        type = lib.types.str;
        description = ''
          github.com Username.
        '';
      };
    };
  };

  tailnetHostSubmodule = lib.types.submodule {
    options = {
      ip = lib.mkOption {
        type        = lib.types.str;
        description = "Stable Tailscale IP (100.x.x.x)";
        example     = "100.64.1.5";
      };
      hostname = lib.mkOption {
        type        = lib.types.str;
        description = "Short hostname as it appears in the tailnet";
        example     = "homeserver";
      };
      magicDnsName = lib.mkOption {
        type        = lib.types.nullOr lib.types.str;
        default     = null;
        description = "Full MagicDNS name, e.g. homeserver.tail1234.ts.net";
      };
    };
  };

  ollamaModelSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type        = lib.types.str;
        description = "Display name for the model.";
        example     = "Qwen 2.5 Coder 14B";
      };
      tools = lib.mkOption {
        type        = lib.types.bool;
        default     = true;
        description = "Whether the model supports tool calling.";
      };
      numCtx = lib.mkOption {
        type        = lib.types.nullOr lib.types.int;
        default     = null;
        description = "Context window size override. Null uses Ollama's default.";
      };
      temperature = lib.mkOption {
        type        = lib.types.nullOr lib.types.float;
        default     = null;
        description = "Sampling temperature. Lower values are more deterministic.";
      };
      think = lib.mkOption {
        type        = lib.types.nullOr lib.types.bool;
        default     = null;
        description = "Enable or disable Qwen3 thinking mode.";
      };
    };
  };
in
{
  imports = [ ../../config.nix ];

  options = {
    me = lib.mkOption {
      type = userSubmodule;
    };

    tailnet = lib.mkOption {
      type        = lib.types.attrsOf tailnetHostSubmodule;
      default     = {};
      description = "Known tailnet hosts, keyed by logical name.";
      example     = lib.literalExpression ''
        {
          homeserver = { ip = "100.64.1.5"; hostname = "homeserver"; };
          laptop     = { ip = "100.64.1.12"; hostname = "laptop"; };
        }
      '';
    };

    ollamaModels = lib.mkOption {
      type        = lib.types.attrsOf ollamaModelSubmodule;
      default     = {};
      description = "Ollama models to load, keyed by model identifier.";
      example     = lib.literalExpression ''
        {
          "qwen2.5-coder:14b" = { name = "Qwen 2.5 Coder 14B"; };
          "deepseek-r1:14b"   = { name = "DeepSeek R1 14B"; };
        }
      '';
    };
  };
}