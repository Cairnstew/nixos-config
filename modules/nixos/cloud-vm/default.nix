{ config, lib, ... }:

let
  cfg = config.my.cloud-vm;
in {
  imports = [
    ./aws.nix
    ./google.nix
  ];

  options.my.cloud-vm = {
    enable = lib.mkEnableOption "Cloud VM profile";

    provider = lib.mkOption {
      type = lib.types.enum [ "aws" "google" ];
      description = "Cloud provider this VM will run on";
    };

    profile = lib.mkOption {
      type = lib.types.enum [ "web" "worker" "bastion" ];
      default = "web";
      description = "VM profile — determines which ports/services are preconfigured";
    };

    openPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Extra TCP ports to open in the NixOS firewall";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
    networking.firewall.enable = true;
    system.stateVersion = "24.11";

    networking.firewall.allowedTCPPorts = {
      web     = [ 80 443 ] ++ cfg.openPorts;
      worker  = cfg.openPorts;
      bastion = [ 22 ] ++ cfg.openPorts;
    }.${cfg.profile};

    services.nginx.enable = lib.mkIf (cfg.profile == "web") true;
  };
}