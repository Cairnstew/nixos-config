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
    group = "zeronsd";
    mode = "770";
  };
  # Dynamically configure zeronsd for each network
  services.zeronsd.servedNetworks."${zerotier_network}" = {
    settings = {
      token = self + "/modules/nixos/linux/token.txt";
      log_level = "trace";
      domain = "zt";
    };
  };
}