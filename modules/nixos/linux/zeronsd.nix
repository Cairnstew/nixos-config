{flake, lib, config, pkgs, ... }:
let
  inherit (flake.config.me) zerotier_network;
  inherit (flake.inputs) self;
in
{
  imports = [
    ./zerotier.nix
  ];

  services.openssh.enable = true;

  age.identityPaths = [ "/root/.ssh/id_ed25519" ];

  # Define the secret via Agenix
  age.secrets."zeronsd-token" = {
    file = self + "/secrets/zeronsd-token.age";
    mode = "770";
  };

  ###### ZeroNSD service ######
  environment.systemPackages = [ pkgs.zeronsd ];

  # Configuration file for ZeroNSD
  environment.etc."zeronsd/${zerotier_network}.yaml".text = ''
    domain: mydomain
    log_level: info
    secret: /var/lib/zerotier-one/authtoken.secret
    token: ${config.age.secrets."zeronsd-token".path}
    wildcard: true
  '';

  systemd.services."zeronsd-${zerotier_network}" = {
    description = "ZeroNSD for ZeroTier network ${zerotier_network}";
    after = [ "network.target" "zerotierone.service" ];
    wants = [ "zerotierone.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.zeronsd}/bin/zeronsd start ${zerotier_network} -c /etc/zeronsd/${zerotier_network}.yaml";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = "ZEROTIER_CENTRAL_TOKEN_FILE=${config.age.secrets."zeronsd-token".path}";
      StandardOutput = "journal";
      StandardError = "journal";
      User = "zeronsd";
      Group = "zeronsd";
      RuntimeDirectory = "zeronsd";
    };

    preStart = ''
      if [ ! -f /etc/zeronsd/${zerotier_network}.yaml ]; then
        echo "Missing config file /etc/zeronsd/${zerotier_network}.yaml"
        exit 1
      fi
    '';
  };

  # Optional: system user for ZeroNSD
  users.users.zeronsd = {
    isSystemUser = true;
    description = "ZeroNSD service user";
    group = "zeronsd";
  };
  users.groups.zeronsd = {};
}
