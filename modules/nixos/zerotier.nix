{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption mkOption mkIf mkDefault types literalExpression
    mapAttrs' nameValuePair concatStringsSep concatLists optional
    filterAttrs;

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

      tokenSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file for the ZeroTier Central
          API token. The module declares age.secrets automatically.
          Use this OR tokenFile, not both.
        '';
      };

      tokenFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the decrypted token at runtime (e.g. from age.secrets).
          Use this if you manage age.secrets yourself.
          Use this OR tokenSecretFile, not both.
        '';
      };

      domain = mkOption {
        type = types.str;
        default = "zt";
        description = "TLD zeronsd will serve.";
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

  # Secret name for a zeronsd network token.
  nsdSecretName = networkId: "zeronsd-token-${networkId}";

  # Networks using tokenSecretFile (auto age.secrets).
  networksWithSecret = filterAttrs
    (_: n: n.tokenSecretFile != null)
    nsd.networks;

  # Resolve the token path — prefer auto-managed secret over manual.
  resolvedTokenFile = netCfg:
    if netCfg.tokenSecretFile != null
    then config.age.secrets.${nsdSecretName netCfg.networkId}.path
    else netCfg.tokenFile;

  # Resolved SSH key path — prefer auto-managed secret over manual.
  resolvedSshKeyFile =
    if zt.sshSecretFile != null
    then config.age.secrets."zt-ssh-key".path
    else zt.sshKeyFile;

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
        description = "MTU to set on ZeroTier interfaces.";
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
        description = "Domains routed to ZeroNSD. Prefix with ~ for routing-only.";
      };

      allowDNS = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run zerotier-cli set <network> allowDNS=1 at boot.
          Disable on the host running zeronsd itself.
        '';
      };

      # ── Inter-host SSH key ─────────────────────────────────────────────────
      sshSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file for the inter-host SSH
          private key. The module declares age.secrets automatically.
          Use this OR sshKeyFile, not both.
        '';
      };

      sshKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the decrypted SSH private key at runtime.
          Use this if you manage age.secrets yourself.
          Use this OR sshSecretFile, not both.
          When either is set, a Host *.zt matchblock is added automatically.
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
        description = ''
          Public key files added to the user's authorized_keys.
          Commit the ZeroTier inter-host public key plaintext to your repo
          and reference it here.
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
          ZeroTier networks to serve DNS for. One systemd service per network.
        '';
        example = literalExpression ''
          {
            "36579ad8f6a82ad3" = {
              tokenSecretFile = flake.inputs.self + /secrets/zeronsd-token.age;
              domain = "zt";
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

      networking.resolvconf.enable = mkDefault false;

      services.resolved = mkIf (zt.dnsServer != null) {
        enable = true;
        extraConfig = ''
          [Resolve]
          DNS=${zt.dnsServer}
          Domains=${concatStringsSep " " zt.dnsDomains}
          FallbackDNS=1.1.1.1
        '';
      };

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

      # Auto-declare age.secrets for the SSH key if sshSecretFile is set.
      age.secrets."zt-ssh-key" = mkIf (zt.sshSecretFile != null) {
        file  = zt.sshSecretFile;
        owner = zt.sshUser;
        mode  = "0600";
      };

      users.users.${zt.sshUser} = mkIf (zt.sshAuthorizedKeyFiles != []) {
        openssh.authorizedKeys.keyFiles = zt.sshAuthorizedKeyFiles;
      };

      programs.ssh.extraConfig =
        mkIf (zt.sshSecretFile != null || zt.sshKeyFile != null) ''
          Host *.zt
            User ${zt.sshUser}
            IdentityFile ${resolvedSshKeyFile}
            ServerAliveCountMax 5
            ServerAliveInterval 60
        '';
    })

    # ── zeronsd ───────────────────────────────────────────────────────────────
    (mkIf (nsd.enable && nsd.networks != {}) {

      networking.firewall.interfaces."zt+" = {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
      };

      services.zerotierone.enable = mkDefault true;

      # Auto-declare age.secrets for networks using tokenSecretFile.
      age.secrets = mapAttrs' (_: netCfg:
        nameValuePair (nsdSecretName netCfg.networkId) {
          file  = netCfg.tokenSecretFile;
          owner = "root";
          mode  = "0400";
        }
      ) networksWithSecret;

      systemd.services = mapAttrs' (_: netCfg:
        let
          networkId = netCfg.networkId;
          tokenPath = resolvedTokenFile netCfg;
          args = concatLists [
            [ "start" ]
            [ "-t" tokenPath ]
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
