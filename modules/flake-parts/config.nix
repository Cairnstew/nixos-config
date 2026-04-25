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
        type = lib.types.str;
        description = "Stable Tailscale IP (100.x.x.x)";
        example = "100.64.1.5";
      };
      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Short hostname as it appears in the tailnet";
        example = "homeserver";
      };
      magicDnsName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Full MagicDNS name, e.g. homeserver.tail1234.ts.net";
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
      type    = lib.types.attrsOf tailnetHostSubmodule;
      default = {};
      description = "Known tailnet hosts, keyed by logical name.";
      example = lib.literalExpression ''
        {
          homeserver = { ip = "100.64.1.5"; hostname = "homeserver"; };
          laptop     = { ip = "100.64.1.12"; hostname = "laptop"; };
        }
      '';
    };
  };
}
