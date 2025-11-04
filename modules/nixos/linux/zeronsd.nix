{flake, lib, config, ... }:
let
  inherit (flake.config.me) zerotier_networks;
  inherit (flake.inputs) self;
in
{
  services.zerotierone.enable = true;

  # Define the secret via Agenix
  #age.secrets."zeronsd-token" = {
  #  file = self + /secrets/zeronsd-token.age;
  #  owner = "zeronsd";
  #  #mode = "0400";
  #};

  # Dynamically configure zeronsd for each network
  #services.zeronsd.servedNetworks =
  #  lib.genAttrs zerotier_networks (networkId: {
  #    settings = {
  #      token = config.age.secrets."zeronsd-token".path;
  #      log_level = "trace";
  #    };
  #  });
}
