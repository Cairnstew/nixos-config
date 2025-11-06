{flake, lib, config, ... }:
let
  inherit (flake.config.me) zerotier_network;
  inherit (flake.inputs) self;
in
{
  imports = [
    ./zerotier.nix
  ];

  #services.zerotierone.enable = true;

  # Define the secret via Agenix
  age.secrets."zeronsd-token" = {
    file = self + /secrets/zeronsd-token.age;
    owner = "root";
  };

  # Dynamically configure zeronsd for each network
  #services.zeronsd.servedNetworks.zerotier_network.settings = {
  #      token = config.age.secrets."zeronsd-token".path;
  #      log_level = "trace";
  #      domain = "zt";
#
  #  };
}
