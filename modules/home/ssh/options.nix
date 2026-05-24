{ lib, flake, pkgs, ... }:

let
  types = lib.types;
  flakeSsh = flake.config.ssh or { };
in
{
  options.my.services.ssh = {
    enable = lib.mkEnableOption "SSH client configuration";

    keyType = lib.mkOption {
      type = types.enum [ "ed25519" "rsa" "ecdsa" ];
      default = flakeSsh.keyType or "ed25519";
      description = "SSH key type to generate.";
    };

    keyPath = lib.mkOption {
      type = types.str;
      default = flakeSsh.keyPath or "~/.ssh/id_ed25519";
      description = "Path to the SSH key file.";
    };

    email = lib.mkOption {
      type = types.str;
      default = flake.config.me.email;
      description = "Email address to use as the SSH key comment.";
    };

    addKeysToAgent = lib.mkOption {
      type = types.bool;
      default = flakeSsh.addKeysToAgent or true;
      description = "Whether to automatically add keys to the SSH agent.";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Additional SSH client configuration.";
    };

    generateKey = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to auto-generate an SSH key on activation if one doesn't exist.";
    };

    enableAgent = lib.mkOption {
      type = types.bool;
      default = pkgs.stdenv.isLinux;
      description = "Whether to enable the SSH agent service (Linux only).";
    };

    identityAgent = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        IdentityAgent socket path added to the global Host * block.
        Set by modules like 1Password rather than owning programs.ssh directly.
      '';
      example = "~/.1password/agent.sock";
    };

    includes = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Files to include in ~/.ssh/config via the Include directive.
        Other modules (e.g. tailscale) append to this list.
      '';
      example = [ "config.d/tailscale" ];
    };

    matchBlocks = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          host = lib.mkOption {
            type = types.str;
            default = "";
            description = "Hostname or IP to match.";
          };
          user = lib.mkOption {
            type = types.str;
            default = "";
            description = "Username to use for this host.";
          };
          port = lib.mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Port to use for this host.";
          };
          identityFile = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Identity file to use for this host.";
          };
          extraOptions = lib.mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Extra SSH options for this host.";
          };
          serverAliveInterval = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Interval in seconds between keepalive messages.";
          };
          serverAliveCountMax = lib.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Number of keepalive messages before disconnecting.";
          };
        };
      });
      default = { };
      description = "SSH match blocks for specific hosts or IPs.";
    };
  };
}
