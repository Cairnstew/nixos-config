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

  # ── Hardware configuration ─────────────────────────────
  hardwareProfiles.gpu.amd = {
    enable = true;
  };

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
    zerotier = {
      enable   = true;
      networks = [ me.zerotier_network ];
      mtu = 1280;
    };

    # zeronsd = {
    #   enable         = true;
    #   zerotierNetwork = me.zerotier_network;
    #   tokenFile      = config.age.secrets."zeronsd-token".path;
    # };
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
