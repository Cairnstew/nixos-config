{flake, lib, config, pkgs, ... }:
let
  inherit (flake.config.me) zerotier_network;
  inherit (flake.inputs) self;
  zeronsd_domain = "home";
in
{
  imports = [
    ./zerotier.nix
  ];

  services.openssh.enable = true;
  services.resolved.enable = true;

  age.identityPaths = [ "/root/.ssh/id_ed25519" ];
  

  # Define the secret via Agenix
  age.secrets."zeronsd-token" = {
    file = self + "/secrets/zeronsd-token.age";
    owner = "zeronsd";
    group = "zeronsd";
    mode = "600";
  };

  ###### ZeroNSD service ######
  environment.systemPackages = [ pkgs.zeronsd ];

  networking.search = [ zeronsd_domain ];

  systemd.services."zeronsd-${zerotier_network}" = {
    description = "ZeroNSD for ZeroTier network ${zerotier_network}";
    after = [ "network.target" "zerotierone.service" ];
    wants = [ "zerotierone.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.zeronsd}/bin/zeronsd start ${zerotier_network} -d ${zeronsd_domain} -t ${config.age.secrets."zeronsd-token".path} -w -v";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = "ZEROTIER_CENTRAL_TOKEN_FILE=${config.age.secrets."zeronsd-token".path}";
      StandardOutput = "journal";
      StandardError = "journal";
      User = "zeronsd";
      Group = "zeronsd";
      RuntimeDirectory = "zeronsd";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    };
  };

  # Optional: system user for ZeroNSD
  users.users.zeronsd = {
    isSystemUser = true;
    description = "ZeroNSD service user";
    group = "zeronsd";
  };
  users.groups.zeronsd = {};
}
