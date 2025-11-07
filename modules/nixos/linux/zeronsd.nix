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
    file = self + /secrets/zeronsd-token.age;
    owner = "zeronsd";
  };

  # Make authtoken.secret group-readable
  systemd.services.zerotierone.serviceConfig.ExecStartPost = "${pkgs.coreutils}/bin/chmod g+r /var/lib/zerotier-one/authtoken.secret";

  # Add zeronsd user to zerotierone group for access
  users.users.zeronsd.extraGroups = [ "zerotierone" ];

  # Dynamically configure zeronsd for each network
  services.zeronsd.servedNetworks."${zerotier_network}" = {
    tokenFile = config.age.secrets."zeronsd-token".path;
    settings = {
      log_level = "trace";
      domain = "zt";
    };
  };
}