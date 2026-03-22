{ config, lib, pkgs, ... }:

let
  cfg = config.services.zeronsd;
  inherit (lib)
    mkEnableOption mkOption mkIf types literalExpression
    mapAttrs' nameValuePair attrValues;

  # Per-network submodule
  networkOpts = { name, ... }: {
    options = {
      networkId = mkOption {
        type = types.strMatching "[0-9a-fA-F]{16}";
        default = name;
        description = ''
          The 16-character ZeroTier network ID to serve DNS for.
          Defaults to the attribute name.
        '';
        example = "36579ad8f6a82ad3";
      };

      tokenFile = mkOption {
        type = types.path;
        description = ''
          Path to a file containing the ZeroTier Central API token.
          Compatible with agenix secrets — set this to your
          <literal>config.age.secrets.zerotierToken.path</literal>.
        '';
        example = literalExpression ''config.age.secrets.zerotierToken.path'';
      };

      domain = mkOption {
        type = types.str;
        default = "home.arpa";
        description = ''
          The TLD / domain suffix zeronsd will serve.
          IANA recommends <literal>home.arpa</literal> for local use.
        '';
        example = "zt.example.com";
      };

      wildcardMode = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable wildcard mode. Every member name gets a wildcard record
          in the form <literal>*.<name>.<tld></literal> pointing at the
          member's IP address(es).
        '';
      };

      hostsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Optional path to an <filename>/etc/hosts</filename>-formatted
          file whose entries are appended to the DNS records.
        '';
        example = literalExpression ''"/etc/zeronsd/extra-hosts"'';
      };

      secretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the ZeroTier <filename>authtoken.secret</filename> used
          to talk to the local <literal>zerotier-one</literal> daemon.
          Leave <literal>null</literal> to let zeronsd auto-detect it
          (the default location is
          <filename>/var/lib/zerotier-one/authtoken.secret</filename>).
        '';
        example = literalExpression ''"/var/lib/zerotier-one/authtoken.secret"'';
      };

      logLevel = mkOption {
        type = types.enum [ "off" "error" "warn" "info" "debug" "trace" ];
        default = "info";
        description = ''
          Log verbosity passed to zeronsd via
          <envar>RUST_LOG</envar> / <envar>ZERONSD_LOG</envar>.
        '';
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Additional command-line arguments forwarded verbatim to
          <command>zeronsd start</command>.
        '';
        example = [ "-v" ];
      };
    };
  };

in
{
  # ---------------------------------------------------------------------------
  # Interface
  # ---------------------------------------------------------------------------
  options.services.zeronsd = {
    enable = mkEnableOption "zeronsd — ZeroTier Central DNS server";

    package = mkOption {
      type = types.package;
      default = pkgs.zeronsd;
      defaultText = literalExpression "pkgs.zeronsd";
      description = "The zeronsd package to use.";
    };

    networks = mkOption {
      type = types.attrsOf (types.submodule networkOpts);
      default = { };
      description = ''
        Attribute set of ZeroTier networks to serve DNS for.
        Each key becomes the default <option>networkId</option> unless
        overridden.  One systemd service is created per network.
      '';
      example = literalExpression ''
        {
          "36579ad8f6a82ad3" = {
            # tokenFile is the only required option when using the attr
            # name as the network ID.
            tokenFile = config.age.secrets.zerotierToken.path;
            domain    = "home.arpa";
          };
        }
      '';
    };
  };

  # ---------------------------------------------------------------------------
  # Implementation
  # ---------------------------------------------------------------------------
  config = mkIf (cfg.enable && cfg.networks != { }) {

    # zerotier-one must already be running so zeronsd can reach its socket.
    services.zerotierone.enable = lib.mkDefault true;

    systemd.services = mapAttrs' (attrName: netCfg:
      let
        networkId = netCfg.networkId;
        svcName   = "zeronsd-${networkId}";

        args = lib.concatLists [
          [ "-t" netCfg.tokenFile ]
          [ "-d" netCfg.domain ]
          (lib.optional (netCfg.secretFile != null) [ "-s" netCfg.secretFile ])
          (lib.optional (netCfg.hostsFile  != null) [ "-f" netCfg.hostsFile  ])
          (lib.optional  netCfg.wildcardMode         [ "-w"                  ])
          netCfg.extraArgs
          [ "start" networkId ]
        ];
      in
      nameValuePair svcName {
        description = "zeronsd DNS server for ZeroTier network ${networkId}";

        # Start after zerotier-one is up and the network is ready.
        after    = [ "zerotierone.service" "network-online.target" ];
        wants    = [ "network-online.target" ];
        requires = [ "zerotierone.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = {
          RUST_LOG     = netCfg.logLevel;
          ZERONSD_LOG  = netCfg.logLevel;
        };

        serviceConfig = {
          ExecStart = lib.escapeShellArgs
            ([ "${cfg.package}/bin/zeronsd" ] ++ args);

          # zeronsd must run as root to bind port 53.
          User  = "root";
          Group = "root";

          # Token file may be an agenix secret; read it at start time, not
          # activation time, so the secret is already decrypted.
          EnvironmentFile = lib.mkIf false "/dev/null"; # placeholder for future env secrets

          Restart          = "on-failure";
          RestartSec       = "5s";
          TimeoutStartSec  = "30s";

          # Minimal hardening — zeronsd needs raw network access (port 53)
          # and the ability to read the zerotier socket.
          AmbientCapabilities  = [ "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
          NoNewPrivileges      = true;
          ProtectSystem        = "strict";
          ProtectHome          = true;
          PrivateTmp           = true;
          ReadOnlyPaths        = [ "/" ];
          # Allow reading the token / secret / hosts paths at runtime.
          ReadWritePaths       = [ ];
        };
      }
    ) cfg.networks;
  };

  meta.maintainers = [ ];
}
