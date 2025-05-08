{ flake, pkgs, config, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixosModules.default
    #inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen4

    ./configuration.nix
  ];

  boot.initrd.kernelModules = [ "nvidia" ];
  services.xserver.videoDrivers = [ "nvidia" ];


  hardware.nvidia-container-toolkit.enable = true;

  hardware.opengl = {
    enable = true;
    #driSupport = true;
    driSupport32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Leave as false unless you're testing the open-source modules
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  nixpkgs.config.allowUnfree = true;
  
  #services.tailscale.enable = true;
  environment.systemPackages = with pkgs; [
    micro
    zed-editor
    calibre
  ];
}