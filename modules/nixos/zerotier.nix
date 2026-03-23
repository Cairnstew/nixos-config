{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption mkOption mkIf mkDefault types literalExpression
    mapAttrs' nameValuePair concatStringsSep concatLists optional;

  zt  = config.my.services.zerotier;
  nsd = config.my.services.zeronsd;

  # ── zeronsd per-network submodule ──────────────────────────────────────────
  networkOpts = { name, ... }: {
    options = {
      networkId = mkOption {
        type = types.strMatching "[0-9a-fA-F]{16}";
        default = name;
        description = "16-character ZeroTier network ID. Defaults to the attribute name.";
        example = "36579ad8f6a82ad3";
      };
      tokenFile = mkOption {
        type = types.path;
        description = ''
          Path to a file containing the ZeroTier Central API token.
          Compatible with agenix — set to config.age.secrets.zeronsd-token.path.
        '';
        example = literalExpression "config.age.secrets.zeronsd-token.path";
      };
      domain = mkOption {
        type = types.str;
        default = "zt";
        description = "TLD zeronsd will serve (e.g. 'zt', 'home.arpa').";
        example = "zt";
      };
      wildcardMode = mkOption {
        type = types.bool;
        default = false;
        description = "Enable wildcard records for all member names.";
      };
      hostsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional /etc/hosts-format file appended to DNS records.";
      };
      secretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to ZeroTier authtoken.secret. Leave null for auto-detection
          at /var/lib/zerotier-one/authtoken.secret.
        '';
      };
      logLevel = mkOption {
        type = types.enum [ "off" "error" "warn" "info" "debug" "trace" ];
        default = "info";
        description = "Log verbosity for zeronsd.";
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra arguments forwarded to 'zeronsd start'.";
        example = [ "-v" ];
      };
    };
  };

in
{
  # ── Options ────────────────────────────────────────────────────────────────
  options.my.services = {

    # ── zerotier-one client ──────────────────────────────────────────────────
    zerotier = {
      enable = mkEnableOption "ZeroTier network service";

      networks = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "8056c2e21c000001" ];
        description = "ZeroTier network IDs to join at boot.";
      };

      mtu = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 1280;
        description = "MTU to set on ZeroTier interfaces. Prevents stalling on large transfers.";
      };

      dnsServer = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "192.168.191.168";
        description = "ZeroNSD server IP for DNS resolution of ZeroTier hostnames.";
      };

      dnsDomains = mkOption {
        type = types.listOf types.str;
        default = [ "~zt" ];
        example = [ "~zt" "~home.arpa" ];
        description = "Domains routed to the ZeroNSD server. Prefix with ~ for routing-only.";
      };

      allowDNS = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run 'zerotier-cli set <network> allowDNS=1' at boot so ZeroTier
          Central pushes DNS config to this machine. Disable on the host
          running zeronsd itself.
        '';
      };

      # ── Inter-host SSH key ─────────────────────────────────────────────────
      sshKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = literalExpression "config.age.secrets.zt-ssh-key.path";
        description = ''
          Path to the private SSH key used for connections between ZeroTier
          hosts. Typically an agenix secret deployed to all machines.
          When set, a Host *.zt matchblock is added to SSH config automatically.
        '';
      };

      sshUser = mkOption {
        type = types.str;
        default = "seanc";
        description = "Username for inter-host ZeroTier SSH connections.";
      };

      sshAuthorizedKeyFiles = mkOption {
        type = types.listOf types.path;
        default = [];
        example = literalExpression "[ ./secrets/zt-ssh-key.pub ]";
        description = ''
          Public key files added to the user's authorized_keys.
          Add the ZeroTier inter-host public key here so all machines accept it.
        '';
      };
    };

    # ── zeronsd DNS server ───────────────────────────────────────────────────
    zeronsd = {
      enable = mkEnableOption "zeronsd — ZeroTier Central DNS server";

      package = mkOption {
        type = types.package;
        default = pkgs.zeronsd;
        defaultText = literalExpression "pkgs.zeronsd";
        description = "The zeronsd package to use.";
      };

      networks = mkOption {
        type = types.attrsOf (types.submodule networkOpts);
        default = {};
        description = ''
          Attribute set of ZeroTier networks to serve DNS for.
          Each key is the network ID. One systemd service is created per network.
        '';
        example = literalExpression ''
          {
            "36579ad8f6a82ad3" = {
              tokenFile = config.age.secrets.zeronsd-token.path;
              domain    = "zt";
            };
          }
        '';
      };
    };
  };

  # ── Implementation ─────────────────────────────────────────────────────────
  config = lib.mkMerge [

    # ── zerotier-one ──────────────────────────────────────────────────────────
    (mkIf zt.enable {
      services.zerotierone = {
        enable = true;
        joinNetworks = zt.networks;
      };

      # Prevent conflict with nixos-wsl generateResolvConf management.
      networking.resolvconf.enable = mkDefault false;

      # Point systemd-resolved at zeronsd for ZeroTier domains.
      services.resolved = mkIf (zt.dnsServer != null) {
        enable = true;
        extraConfig = ''
          [Resolve]
          DNS=${zt.dnsServer}
          Domains=${concatStringsSep " " zt.dnsDomains}
          FallbackDNS=1.1.1.1
        '';
      };

      # Enable DNS push from ZeroTier Central on client machines.
      systemd.services.zerotier-dns = mkIf (zt.allowDNS && zt.dnsServer != null) {
        description = "Enable ZeroTier DNS push for joined networks";
        wantedBy = [ "multi-user.target" ];
        after    = [ "zerotierone.service" ];
        requires = [ "zerotierone.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "zt-dns" ''
            for network in ${concatStringsSep " " zt.networks}; do
              ${pkgs.zerotierone}/bin/zerotier-cli \
                -D/var/lib/zerotier-one \
                set "$network" allowDNS=1
            done
          '';
        };
      };

      # Set MTU on ZeroTier interfaces to prevent packet fragmentation.
      systemd.services.zerotier-mtu = mkIf (zt.mtu != null) {
        description = "Set MTU on ZeroTier interfaces";
        wantedBy = [ "multi-user.target" ];
        after    = [ "zerotierone.service" "network-online.target" ];
        wants    = [ "network-online.target" ];
        requires = [ "zerotierone.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
          ExecStart = pkgs.writeShellScript "zt-mtu" ''
            for iface in $(${lib.getExe' pkgs.iproute2 "ip"} -o link show \
              | ${pkgs.gnugrep}/bin/grep -oP '^\d+:\s+\Kzt\S+(?=@|:)'); do
              echo "Setting MTU on $iface to ${toString zt.mtu}"
              ${lib.getExe' pkgs.iproute2 "ip"} link set "$iface" mtu ${toString zt.mtu}
            done
          '';
        };
      };

      # Add the ZeroTier inter-host public key to authorized_keys.
      users.users.${zt.sshUser} = mkIf (zt.sshAuthorizedKeyFiles != []) {
        openssh.authorizedKeys.keyFiles = zt.sshAuthorizedKeyFiles;
      };

      # SSH matchblock for *.zt hosts using the shared inter-host key.
      programs.ssh.extraConfig = mkIf (zt.sshKeyFile != null) ''
        Host *.zt
          User ${zt.sshUser}
          IdentityFile ${zt.sshKeyFile}
          ServerAliveCountMax 5
          ServerAliveInterval 60
      '';
    })

    # ── zeronsd ───────────────────────────────────────────────────────────────
    (mkIf (nsd.enable && nsd.networks != {}) {

      # Open port 53 on ZeroTier interfaces for DNS queries from peers.
      networking.firewall.interfaces."zt+" = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };

      # zerotier-one must be running so zeronsd can reach its socket.
      services.zerotierone.enable = mkDefault true;

      systemd.services = mapAttrs' (_attrName: netCfg:
        let
          networkId = netCfg.networkId;
          args = concatLists [
            [ "start" ]
            [ "-t" netCfg.tokenFile ]
            [ "-d" netCfg.domain ]
            (optional (netCfg.secretFile != null) "-s")
            (optional (netCfg.secretFile != null) netCfg.secretFile)
            (optional (netCfg.hostsFile  != null) "-f")
            (optional (netCfg.hostsFile  != null) netCfg.hostsFile)
            (optional  netCfg.wildcardMode        "-w")
            netCfg.extraArgs
            [ networkId ]
          ];
        in
        nameValuePair "zeronsd-${networkId}" {
          description = "zeronsd DNS server for ZeroTier network ${networkId}";
          after    = [ "zerotierone.service" "network-online.target" ];
          wants    = [ "network-online.target" ];
          requires = [ "zerotierone.service" ];
          wantedBy = [ "multi-user.target" ];

          environment = {
            RUST_LOG    = netCfg.logLevel;
            ZERONSD_LOG = netCfg.logLevel;
          };

          serviceConfig = {
            ExecStart = lib.escapeShellArgs
              ([ "${nsd.package}/bin/zeronsd" ] ++ args);
            User  = "root";
            Group = "root";

            Restart         = "on-failure";
            RestartSec      = "5s";
            TimeoutStartSec = "30s";

            AmbientCapabilities   = [ "CAP_NET_BIND_SERVICE" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            NoNewPrivileges       = true;
            ProtectSystem         = "strict";
            ProtectHome           = true;
            PrivateTmp            = true;
            ReadOnlyPaths         = [ "/" ];
            ReadWritePaths        = [ ];
          };
        }
      ) nsd.networks;
    })
  ];
}
