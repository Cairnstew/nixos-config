{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  # ── SSH configuration ───────────────────────────────────
  #nixos-unified.sshTarget = "seanc@server";

  # ── Imports ────────────────────────────────────────────
  imports = [
    ./configuration.nix
    self.nixosModules.default
  ];


  # ── Hardware configuration ─────────────────────────────
  #hardwareProfiles.gpu.nvidia = {
  #  enable   = true;
  #  headless = true;   # skips graphics stack and X server entirely
  #  toolkit  = true;
  #};
  
  # ── System settings ────────────────────────────────────
  my.system = {
    location = {
      enable    = true;
      timeZone  = "GB";
      latitude  = 55.8617;
      longitude = 4.2583;
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
