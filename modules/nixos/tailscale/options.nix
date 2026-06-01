{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types literalExpression;

  grantSubmodule = types.submodule {
    options = {
      src = mkOption {
        type = types.listOf types.str;
        description = "Source hosts or tag for this grant.";
      };
      dst = mkOption {
        type = types.listOf types.str;
        description = "Destination hosts or tags for this grant.";
      };
      ip = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "IP addresses or ports to allow.";
        example = [ "tcp:22" "100.0.0.0/8" ];
      };
      app = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Allow access to specific applications.";
      };
      via = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Subnet router(s) to route traffic through.";
      };
      srcPosture = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Posture checks required from the source device.";
      };
    };
  };

  sshSubmodule = types.submodule {
    options = {
      action = mkOption {
        type = types.enum [ "accept" "check" "match" ];
        description = "SSH action: accept (allow without auth), check (require auth), match (principal matching).";
      };
      src = mkOption {
        type = types.listOf types.str;
        description = "Source users, groups, or tags.";
      };
      dst = mkOption {
        type = types.listOf types.str;
        description = "Destination hosts or tags.";
      };
      users = mkOption {
        type = types.listOf types.str;
        description = "Destination users to allow SSH access to.";
      };
      checkPeriod = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Re-authentication period (e.g. '12h', '24h'). Only valid for action='check'.";
      };
      acceptEnv = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Environment variables to accept from the client.";
      };
    };
  };

  aclSubmodule = types.submodule {
    options = {
      action = mkOption {
        type = types.enum [ "accept" "deny" ];
        default = "accept";
        description = "ACL action.";
      };
      src = mkOption {
        type = types.listOf types.str;
        description = "Source hosts, tags, or user groups.";
      };
      dst = mkOption {
        type = types.listOf types.str;
        description = "Destination hosts, tags, or ports.";
      };
      proto = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Protocol to allow (e.g. 'tcp', 'udp', 'icmp').";
      };
    };
  };
in
{
  options.my.services.tailscale = {
    enable = mkEnableOption "Tailscale mesh VPN";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Tailscale UDP port in the firewall.";
    };

    exitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Advertise this machine as a Tailscale exit node.";
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "tag:nixos" "tag:personal" ];
      description = "Tailscale ACL tags to advertise for this machine.";
    };

    ssh = {
      enable = mkEnableOption "Static SSH config for tailnet machines";

      user = mkOption {
        type = types.str;
        description = "Local user whose SSH config will be managed.";
        example = "alice";
      };

      publicKeyPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the Tailscale SSH public key to authorise on this host.";
      };

      extraHostConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra lines appended inside every generated Host block (e.g. 'ForwardAgent yes').";
        example = "ForwardAgent yes\nServerAliveInterval 60";
      };
    };

    manager = {
      enable = mkEnableOption "Tailscale auth key and ACL management via tailscale-manager (OAuth-based)";

      tailnet = mkOption {
        type = types.str;
        default = "-";
        description = ''
          Tailscale tailnet name. Use "-" to auto-resolve from the OAuth credential.
        '';
      };

      tags = mkOption {
        type = types.listOf types.str;
        default = config.my.services.tailscale.tags;
        defaultText = literalExpression "config.my.services.tailscale.tags";
        description = "Tags for managed auth keys. Defaults to the parent tailscale tags.";
      };

      acl = {
        enable = mkEnableOption "Tailscale ACL management";
      };

      providerVersion = mkOption {
        type = types.str;
        default = "~> 0.29";
        description = "Tailscale Terraform provider version constraint.";
      };

      policy = {
        enable = mkEnableOption "Structured Tailscale policy (grants, SSH rules, tag owners)";

        tagOwners = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          example = { "tag:nixos" = [ "autogroup:admin" ]; };
          description = "Tag ownership mapping — which owners can assign which tags.";
        };

        interNodePorts = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "tcp:22" "tcp:443" ];
          description = ''
            Ports to open between tag:nixos nodes.
            Each string should be in "proto:port" or "addr:proto:port" format
            (e.g. "tcp:22", "tcp:443", "100.64.0.0/10:tcp:443").
            Generates grants: src=[tag:nixos] dst=[tag:nixos] ip=[...].
          '';
        };

        grants = mkOption {
          type = types.listOf grantSubmodule;
          default = [ ];
          description = "Access grants defining who can reach what on which ports.";
        };

        ssh = mkOption {
          type = types.listOf sshSubmodule;
          default = [ ];
          description = "SSH access rules for tailnet machines.";
        };

        acls = mkOption {
          type = types.listOf aclSubmodule;
          default = [ ];
          description = "Additional ACL rules beyond grants (accept/deny).";
        };

        extraConfig = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = ''
            Extra top-level policy fields not covered by the typed options
            (e.g. groups, hosts, nodeAttrs, autoApprovers, derpMap).
            These are merged directly into the serialized policy JSON.
          '';
          example = {
            groups = {
              "group:dev" = [ "alice@example.com" "bob@example.com" ];
            };
          };
        };
      };
    };
  };
}
