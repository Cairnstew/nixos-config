{flake, lib, config, pkgs, cfg, ... }:
let
  inherit (flake.config.me) zerotier_network;
  inherit (flake.inputs) self;
in
{
  imports = [
    ./zerotier.nix
  ];

  # Define the secret via Agenix
  age.secrets."zeronsd-token" = {
    file = self + "/secrets/zeronsd-token.age";
    owner = "zeronsd";
    group = "zeronsd";
    mode = "640";
    symlink = false;
    # symlink is true by default; usually fine
  };


  services.zeronsd = {
    enable = true;
    networkId = zerotier_network;
    settings = {
      token = config.age.secrets."zeronsd-token".path;
      domain = "myhome.arpa";
      log_level = "info";
      #wildcard = true;
    };
  };


  options.services.zeronsd = {
    enable = lib.mkEnableOption "Zeronsd DNS service for ZeroTier networks";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.zeronsd;
      description = "The zeronsd package to use.";
    };

    networkId = lib.mkOption {
      type = lib.types.str;
      example = "36579ad8f6a82ad3";
      description = "ZeroTier network ID to serve DNS for.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/zeronsd/config.yaml";
      description = "Path to zeronsd configuration file.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        token = "/var/lib/zeronsd/.central.token";
        log_level = "info";
        secret = "/var/lib/zerotier-one/authtoken.secret";
        wildcard = false;
      };
      description = ''
        YAML configuration options for zeronsd. These are written to config.yaml.
      '';
      example = {
        token = "/run/secrets/zeronsd-token";
        domain = "example.arpa";
        log_level = "debug";
        wildcard = true;
      };
    };

    # optional: handle secret integration via Agenix or similar
    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = cfg.settings.token or "/run/secrets/zeronsd-token";
      description = "Path to the ZeroTier Central API token file.";
    };
  };
  config = lib.mkIf cfg.enable {
    # Ensure the zeronsd user exists
    users.users.zeronsd = {
      isSystemUser = true;
      group = "zeronsd";
    };
    users.groups.zeronsd = {};

    environment.etc."zeronsd/config.yaml".source = pkgs.writeText "zeronsd-config.yaml" (lib.generators.toYAML {} cfg.settings);

    systemd.services."zeronsd-${cfg.networkId}" = {
      description = "ZeroTier Network DNS (zeronsd) for ${cfg.networkId}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "zerotierone.service" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/zeronsd start ${cfg.networkId} -c ${cfg.configFile}";
        DynamicUser = false;
        User = "zeronsd";
        Group = "zeronsd";
        Restart = "on-failure";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ]; # Needed for port 53
      };
    };
  };
}