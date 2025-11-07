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

  # Dynamically configure zeronsd for each network
  services.zeronsd.servedNetworks."${zerotier_network}" = {
    settings = {
      #token = config.age.secrets.zeronsd-token.path;
      token = self + "/secrets/zeronsd-token.txt";
      log_level = "trace";
      domain = "zt";
    };
  };
}