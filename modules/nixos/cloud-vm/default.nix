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

    hostPlatform = lib.mkOption {        # ← new
      type = lib.types.str;
      default = "x86_64-linux";
      description = "The system platform for this cloud VM (sets nixpkgs.hostPlatform).";
      example = "aarch64-linux";
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
    nixpkgs.hostPlatform = lib.mkDefault cfg.hostPlatform;    # ← new

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