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
    owner = "zeronsd";
    group = "zeronsd";
    mode = "770";
  };

  services.zerotierone-with-dns = {
    enable = true;
    networks = {
      "homenet.zt" = zerotier_network;
      #"gamenet.zt" = "<ZEROTIER NETWORK ID>";
    };
  };
}
