{flake, lib, config, pkgs, ... }:
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

  # Ensure zeronsd user exists
  users.users.zeronsd = {
    isSystemUser = true;
    group = "zeronsd";
  };
  users.groups.zeronsd = {};

  # Install zeronsd package
  environment.systemPackages = [
    pkgs.zeronsd
  ];

  # Generate /etc/zeronsd/config.yaml
  environment.etc."zeronsd/config.yaml".source = pkgs.writeText "zeronsd-config.yaml" ''
    token: "${config.age.secrets."zeronsd-token".path}"
    domain: "home.arpa"
    log_level: "info"
    secret: "/var/lib/zerotier-one/authtoken.secret"
    wildcard: false
  '';

  # Create systemd service
  systemd.services."zeronsd-${zerotier_network}" = {
    description = "ZeroTier Network DNS (zeronsd) for ${zerotier_network}";
    after = [ "network.target" "zerotierone.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zeronsd}/bin/zeronsd start ${zerotier_network} -c /etc/zeronsd/config.yaml";
      User = "zeronsd";
      Group = "zeronsd";
      Restart = "on-failure";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ]; # needed for port 53
    };
  };
}
