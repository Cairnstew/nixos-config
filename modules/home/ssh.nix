{ pkgs, config, lib, flake, ... }:
let
  cfg = config.my.services.ssh;
  # Use flake config ssh settings as defaults
  flakeSsh = flake.config.ssh or { };
in
{
  options.my.services.ssh = {
    enable = lib.mkEnableOption "SSH configuration";

    keyType = lib.mkOption {
      type = lib.types.enum [ "ed25519" "rsa" "ecdsa" ];
      # Use flake config ssh.keyType as default
      default = flakeSsh.keyType or "ed25519";
      description = "SSH key type to generate. Defaults to config.ssh.keyType.";
    };

    keyPath = lib.mkOption {
      type = lib.types.str;
      # Use flake config ssh.keyPath as default
      default = flakeSsh.keyPath or "~/.ssh/id_ed25519";
      description = "Path to the SSH key file. Defaults to config.ssh.keyPath.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = flake.config.me.email;
      description = "Email address to use as the SSH key comment.";
    };

    addKeysToAgent = lib.mkOption {
      type = lib.types.bool;
      # Use flake config ssh.addKeysToAgent as default
      default = flakeSsh.addKeysToAgent or true;
      description = "Whether to automatically add keys to the SSH agent. Defaults to config.ssh.addKeysToAgent.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional SSH client configuration.";
    };

    generateKey = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to auto-generate an SSH key on activation if one doesn't exist.";
    };

    enableAgent = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isLinux;
      description = "Whether to enable the SSH agent service (Linux only).";
    };

    # ── Unified options — other modules contribute here ──────────────────────

    identityAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        IdentityAgent socket path added to the global Host * block.
        Set by modules like 1Password rather than owning programs.ssh directly.
      '';
      example = "~/.1password/agent.sock";
    };

    includes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Files to include in ~/.ssh/config via the Include directive.
        Other modules (e.g. tailscale) append to this list.
      '';
      example = [ "config.d/tailscale" ];
    };

    matchBlocks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Hostname or IP to match.";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Username to use for this host.";
          };
          port = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            description = "Port to use for this host.";
          };
          identityFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Identity file to use for this host.";
          };
          extraOptions = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Extra SSH options for this host.";
          };
          serverAliveInterval = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            # Use flake config ssh.serverAliveInterval as default for new blocks
            default = null;
            description = "Interval in seconds between keepalive messages.";
          };
          serverAliveCountMax = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Number of keepalive messages before disconnecting.";
          };
        };
      });
      default = { };
      description = "SSH match blocks for specific hosts or IPs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Set global SSH keepalive from flake config
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = cfg.includes;

      extraConfig = lib.concatStringsSep "\n" (
        lib.optional cfg.addKeysToAgent "AddKeysToAgent yes"
        ++ lib.optional (cfg.identityAgent != null) "IdentityAgent ${cfg.identityAgent}"
        # Add global ServerAliveInterval from flake config
        ++ lib.optional ((flakeSsh.serverAliveInterval or 0) != 0)
          "ServerAliveInterval ${toString (flakeSsh.serverAliveInterval or 60)}"
        ++ lib.optional (cfg.extraConfig != "") cfg.extraConfig
      );

      matchBlocks = lib.recursiveUpdate
        {
          "*" = {
            sendEnv = [ "LANG" "LC_*" ];
            hashKnownHosts = true;
          };
        }
        (lib.mapAttrs
          (_: block:
            {
              extraOptions = block.extraOptions
              // lib.optionalAttrs (block.serverAliveInterval != null) {
                ServerAliveInterval = toString block.serverAliveInterval;
              }
              // lib.optionalAttrs (block.serverAliveCountMax != null) {
                ServerAliveCountMax = toString block.serverAliveCountMax;
              };
            }
            // lib.optionalAttrs (block.host != "") { hostname = block.host; }
            // lib.optionalAttrs (block.user != "") { inherit (block) user; }
            // lib.optionalAttrs (block.port != null) { inherit (block) port; }
            // lib.optionalAttrs (block.identityFile != null) { inherit (block) identityFile; }
          )
          cfg.matchBlocks);
    };

    home.activation.generateSSHKey = lib.mkIf cfg.generateKey (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f ${cfg.keyPath} ]; then
          mkdir -p $(dirname ${cfg.keyPath})
          ${pkgs.openssh}/bin/ssh-keygen \
            -t ${cfg.keyType} \
            -C "${cfg.email}" \
            -f ${cfg.keyPath} \
            -N ""
          echo "Generated new SSH key (${cfg.keyType}) for ${cfg.email}"
        fi
      ''
    );

    services.ssh-agent = lib.mkIf cfg.enableAgent { enable = true; };
  };
}
