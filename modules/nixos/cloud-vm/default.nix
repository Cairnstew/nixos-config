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
      type        = lib.types.enum [ "aws" "google" ];
      description = "Cloud provider this VM will run on";
    };

    hostPlatform = lib.mkOption {
      type        = lib.types.str;
      default     = "x86_64-linux";
      description = "The system platform for this cloud VM (sets nixpkgs.hostPlatform)";
      example     = "aarch64-linux";
    };

    profile = lib.mkOption {
      type        = lib.types.enum [ "web" "worker" "bastion" ];
      default     = "web";
      description = "VM profile — determines which ports/services are preconfigured";
    };

    openPorts = lib.mkOption {
      type        = lib.types.listOf lib.types.port;
      default     = [];
      description = "Extra TCP ports to open in the NixOS firewall";
    };

    instanceType = lib.mkOption {
      type        = lib.types.str;
      default     = "t3.micro";
      example     = "t3.small";
      description = "Cloud instance/machine type (e.g. t3.micro for AWS, e2-micro for GCP)";
    };

    nixosRelease = lib.mkOption {
      type        = lib.types.str;
      default     = "24.11";
      description = "NixOS release used for the AMI/image lookup in Terraform";
    };

    region = lib.mkOption {
      type        = lib.types.str;
      description = "Cloud provider region for this VM";
      example     = "eu-west-1";
    };

    secretsPath = lib.mkOption {
      type        = lib.types.str;
      description = "Runtime path agenix decrypts the provider credentials to (read by flake tooling, not NixOS config)";
      example     = "/run/agenix/aws-labs";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = lib.mkDefault cfg.hostPlatform;

    services.openssh = {
      enable                 = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin        = "no";
    };

    networking.firewall = {
      enable           = true;
      allowedTCPPorts  = {
        web     = [ 80 443 ] ++ cfg.openPorts;
        worker  = cfg.openPorts;
        bastion = [ 22 ] ++ cfg.openPorts;
      }.${cfg.profile};
    };

    # nginx only makes sense on web profile — other profiles leave it absent
    # entirely rather than disabled, so no unnecessary service unit is generated
    services.nginx.enable = cfg.profile == "web";

    system.stateVersion = cfg.nixosRelease;
  };
}