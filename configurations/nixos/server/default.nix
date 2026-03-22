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
    enable = true;
    modesetting = true;
  };

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
      users = [ user ];
    };
  };

  age.secrets = {
      "zeronsd-token" = {
        file = flake.inputs.self + /secrets/zeronsd-token.age;
        owner = "root";
        mode = "0400";
      };
    };

  # ── System services ────────────────────────────────────
  my.services = {
    zerotier = {
      enable   = true;
      networks = [ me.zerotier_network ];
      mtu = 1280;
    };
    zeronsd = {
      enable = true;
      networks.${me.zerotier_network}.tokenFile = config.age.secrets.zeronsd-token.path;
    };
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

  
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/aaf609bd-e320-4d13-a9a6-fc2cc5cd0f3a";
    fsType = "ext4";
  };
}
