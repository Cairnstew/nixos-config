{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  # ── Imports ────────────────────────────────────────────
  imports = [
    ./configuration.nix
    self.nixosModules.default
    flake.inputs.nixos-wsl.nixosModules.default
  ];
  users.users.${user} = {
    uid = 1000;
  };
  wsl.defaultUser = user;
  nixpkgs.hostPlatform = "x86_64-linux";

  wsl.wslConf.network.generateResolvConf = false;
  networking.useHostResolvConf = false;

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "100.100.100.100"
  ];

  networking.search = [ "lan" ]; # optional

  my.build.default = "tarballBuilder";

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
    waydroid = {
      enable = false;
    };
    docker = {
      enable = true;
      users = [ user ];
    };
  };

  # ── System services ────────────────────────────────────
  my.services = {
    
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
        #vscode.enable = true;
        rstudio.enable            = true;
        obsidian.enable           = true;
      };
    };
    services.vscode-server.enable = true;
  };
}
