{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  # ── SSH configuration ───────────────────────────────────
  nixos-unified.sshTarget = "seanc@server";

  # ── Imports ────────────────────────────────────────────
  imports = [
    ./configuration.nix
    self.nixosModules.default
  ];

  # ── Hardware configuration ─────────────────────────────
  hardwareProfiles.gpu.nvidia = {
    enable   = true;
    headless = true;
    open     = false;
    toolkit  = true;
    cuda     = true;
  };

  my.services.ollama = {
    enable = true;
    acceleration = "cuda";
    loadModels = [ "qwen2.5-coder:7b" "deepseek-r1:14b" ];
    models = "/mnt/data/models";
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cuda.acceptLicense = true;
  
  # ── System settings ────────────────────────────────────
  my.system = {
    location = {
      enable    = true;
      timeZone  = "America/Chicago";
      latitude  = 30.2672;
      longitude = -97.7431;
    };
    battery = {
      enable = false;
    };
  };

  # ── System programs ────────────────────────────────────
  my.programs = {
    #spotify.enable = true;

  };

  # ── System tools ───────────────────────────────────────
  my.tools = {
    uup-converter.enable = false;
  };  

  # Virtualisation
  my.virtualisation = {
    waydroid = {
      enable = false;
    };
    docker = {
      enable = true;
      users = [ flake.config.me.username ];
      enableNvidiaContainerToolkit = true;
    };
  };

  # ── System services ────────────────────────────────────
  my.services = {
    #zerotier = {
    #  enable = true;
    #  allowDNS = false;
    #};
  };

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.get-template
    pkgs.screen
    pkgs.terraform
  ];

  # ── Home Manager configuration ─────────────────────────
  home-manager.users.${user} = {
    imports = [
      "${flake.inputs.nixos-vscode-server}/modules/vscode-server/home.nix"
    ];
    
    my = {
      programs = {
      };
    };
    services.vscode-server.enable = true;
  };
}
