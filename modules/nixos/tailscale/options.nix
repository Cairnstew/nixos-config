{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types literalExpression;

  appCapabilityType = types.attrsOf (types.listOf (
    types.submodule {
      freeformType = types.attrs;
    }
  ));

  derpNodeType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
      };
      regionID = mkOption {
        type = types.int;
      };
      hostName = mkOption {
        type = types.str;
      };
      stunPort = mkOption {
        type = types.int;
        default = 3478;
      };
      stunOnly = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  derpRegionType = types.submodule {
    options = {
      regionID = mkOption {
        type = types.int;
      };
      regionCode = mkOption {
        type = types.str;
      };
      regionName = mkOption {
        type = types.str;
      };
      nodes = mkOption {
        type = types.listOf derpNodeType;
      };
    };
  };

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
        type = types.nullOr appCapabilityType;
        default = null;
        description = "Application-layer capabilities (e.g. tailsql, golink).";
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
        type = types.nullOr (types.listOf types.str);
        default = null;
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
      srcPosture = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Posture conditions restricting the SSH client.";
        example = [ "posture:latestMac" ];
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

  testSubmodule = types.submodule {
    options = {
      src = mkOption {
        type = types.str;
        description = "Source identity to test from (user, group, tag, or host).";
      };
      srcPostureAttrs = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = "Posture attributes to simulate for this test.";
      };
      proto = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Protocol to test (tcp, udp, icmp).";
      };
      accept = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Destinations that should be reachable.";
      };
      deny = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Destinations that should be blocked.";
      };
    };
  };

  sshTestSubmodule = types.submodule {
    options = {
      src = mkOption {
        type = types.str;
        description = "SSH client identity.";
      };
      dst = mkOption {
        type = types.listOf types.str;
        description = "SSH destinations.";
      };
      accept = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "SSH usernames that should be accepted without checks.";
      };
      check = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "SSH usernames that should require re-auth checks.";
      };
      deny = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "SSH usernames that should be denied.";
      };
      srcPostureAttrs = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = "Posture attributes to simulate for this test.";
      };
    };
  };

  appConnectorSubmodule = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Human-readable connector name.";
      };
      connectors = mkOption {
        type = types.listOf types.str;
        description = "Tags of devices acting as app connectors.";
      };
      domains = mkOption {
        type = types.listOf types.str;
        description = "Domains the connector proxies.";
      };
      routes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Optional CIDR routes the connector proxies.";
      };
    };
  };

  authKeySubmodule = types.submodule ({ name, config, ... }: {
    options = {
      description = mkOption {
        type = types.str;
        description = "Human-readable description for this auth key.";
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Tags to apply to this auth key.";
      };
      reusable = mkOption {
        type = types.bool;
        default = true;
        description = "Allow multiple devices to use this key.";
      };
      ephemeral = mkOption {
        type = types.bool;
        default = false;
        description = "Ephemeral devices are removed on disconnect.";
      };
      preauthorized = mkOption {
        type = types.bool;
        default = true;
        description = "Pre-approve devices using this key.";
      };
      recreateIfInvalid = mkOption {
        type = types.enum [ "always" "never" ];
        default = "always";
        description = "Whether to recreate key if invalid (expired, revoked, deleted).";
      };

      exportPath = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Write the auth key value to a file on disk after terraform apply.";
        };

        path = mkOption {
          type = types.path;
          default = "/var/lib/tailscale-manager/keys/${name}";
          defaultText = literalExpression ''"/var/lib/tailscale-manager/keys/<name>"'';
          description = "Path where the key value is written.";
        };

        owner = mkOption {
          type = types.str;
          default = "root";
          description = "Owner of the key file.";
        };

        group = mkOption {
          type = types.str;
          default = "root";
          description = "Group of the key file.";
        };

        mode = mkOption {
          type = types.str;
          default = "0600";
          description = "File permissions (octal string, e.g. \"0600\", \"0640\").";
        };
      };

    };
  });

  nodeAttrsSubmodule = types.submodule {
    options = {
      target = mkOption {
        type = types.listOf types.str;
        description = "Which nodes the attributes apply to.";
      };
      attr = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Device attributes (funnel, nextdns:<id>, disable-ipv4, etc.).";
      };
      app = mkOption {
        type = types.nullOr appCapabilityType;
        default = null;
        description = "App-layer capabilities (app connectors).";
      };
    };
  };

  autoApproversSubmodule = types.submodule {
    options = {
      routes = mkOption {
        type = types.nullOr (types.attrsOf (types.listOf types.str));
        default = null;
        description = "CIDR range to authorized approvers.";
      };
      exitNode = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Authorized approvers for exit node advertisements.";
      };
      appConnectors = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Authorized approvers for app connector advertisements.";
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

    acceptRoutes = mkOption {
      type = types.bool;
      default = false;
      description = "Accept subnet routes advertised by other Tailscale nodes.";
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "tag:nixos" "tag:personal" ];
      description = "Tailscale ACL tags to advertise for this machine.";
    };

    ssh = {
      enable = mkEnableOption "Tailscale SSH server (--ssh flag) + generate client SSH config for tailnet machines";

      user = mkOption {
        type = types.str;
        description = "Local user whose SSH config will be managed.";
        example = "alice";
      };

      identityFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the SSH private key used to connect to tailnet machines.";
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

      authKeys = mkOption {
        type = types.attrsOf authKeySubmodule;
        default = { };
        description = ''
          Declare multiple auth keys. When non-empty, these replace the
          top-level tags and recreateIfInvalid options.
        '';
        example = {
          ci-key = {
            description = "CI pipeline key";
            tags = [ "tag:ci" ];
            ephemeral = true;
          };
        };
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

        groups = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = "Named groups of users.";
          example = {
            "group:engineering" = [ "alice@example.com" "bob@example.com" ];
          };
        };

        hosts = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Named IP/CIDR aliases for use in access rules.";
          example = {
            "jump-box" = "100.100.100.100";
          };
        };

        ipsets = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = "Named IP collections.";
        };

        postures = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = "Device posture condition expressions.";
        };

        nodeAttrs = mkOption {
          type = types.listOf nodeAttrsSubmodule;
          default = [ ];
          description = "Per-device attributes (NextDNS, Funnel, randomize-client-port, app connectors).";
        };

        appConnectors = mkOption {
          type = types.listOf appConnectorSubmodule;
          default = [ ];
          description = ''
            Declarative app connector configuration.
            Synthesizes the correct nodeAttrs entry with tailscale.com/app-connectors capability.
          '';
        };

        autoApprovers = mkOption {
          type = autoApproversSubmodule;
          default = { };
          description = "Users/groups/tags that can bypass approval for routes and exit nodes.";
        };

        derpMap = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              omitDefaultRegions = mkOption {
                type = types.bool;
                default = false;
                description = "Disable Tailscale-provided DERP servers.";
              };
              regions = mkOption {
                type = types.attrsOf derpRegionType;
                default = { };
                description = "Custom DERP regions.";
              };
            };
          });
          default = null;
          description = "Custom DERP relay server configuration.";
        };

        tests = mkOption {
          type = types.listOf testSubmodule;
          default = [ ];
          description = "ACL/grant assertion tests — policy is rejected if they fail.";
        };

        sshTests = mkOption {
          type = types.listOf sshTestSubmodule;
          default = [ ];
          description = "SSH assertion tests — policy is rejected if they fail.";
        };

        disableIPv4 = mkOption {
          type = types.bool;
          default = false;
          description = "Stop assigning IPv4 Tailscale addresses.";
        };

        randomizeClientPort = mkOption {
          type = types.bool;
          default = false;
          description = "Use random WireGuard port instead of 41641.";
        };

        oneCGNATRoute = mkOption {
          type = types.str;
          default = "";
          description = "CGNAT route behavior: '' (default), 'mac-always', or 'mac-never'.";
        };

        extraConfig = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = ''
            Extra top-level policy fields not covered by the typed options above
            (e.g. groups, hosts, derpMap).
            These are merged directly into the serialized policy JSON.
          '';
          example = {
            groups = {
              "group:dev" = [ "alice@example.com" "bob@example.com" ];
            };
          };
        };
      };

      agenixIntegration = {
        enable = mkEnableOption "Extract the generated auth key into agenix-manager after terraform apply";

        secretName = mkOption {
          type = types.str;
          default = "tailscale-auth-key";
          description = "Name of the agenix secret to create or overwrite.";
        };

        secretScope = mkOption {
          type = types.str;
          default = "systems";
          description = "Key scope passed to agenix-manager new --scope.";
        };

        agenixManagerBin = mkOption {
          type = types.path;
          description = "Path to the agenix-manager binary.";
          example = literalExpression ''"''${pkgs.agenix-manager}/bin/agenix-manager"'';
        };
      };
    };
  };
}
