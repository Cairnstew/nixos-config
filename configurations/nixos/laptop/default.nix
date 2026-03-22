{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  # ── SSH configuration ───────────────────────────────────
  nixos-unified.sshTarget = "seanc@laptop";

  # ── Imports ────────────────────────────────────────────
  imports = [
    ./configuration.nix
    self.nixosModules.default
  ];

  # ── Hardware configuration ─────────────────────────────
  hardwareProfiles.gpu.mesa.enable = true;

  # ── System settings ────────────────────────────────────
  my.system = {
    location = {
      enable    = true;
      timeZone  = "GB";
      latitude  = 55.8617;
      longitude = 4.2583;
    };
    battery = {
      enable = true;
      lidSwitch = "ignore";
      disableSuspend = false; 
   
    };
  };

  # ── System programs ────────────────────────────────────
  my.programs = {
    spotify.enable = true;

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
    zerotier.enable   = true;

    natShare = {
      enable = true;
      wanInterface = "wlp170s0";   # check yours with `ip link`
      lanInterface = "enp0s13f0u2";  # check yours with `ip link`
    };
  };

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.get-template
    pkgs.rustdesk
  ];

  # ── Home Manager configuration ─────────────────────────
  home-manager.users.${user}.my = {
    programs = {
      cudatext.enable           = true;
      discord.enable            = true;
      firefox.enable            = true;
      localsend.enable          = true;
      obsidian.enable           = true;
      rstudio.enable            = true;
      #steam.enable            = true;
      vscode.enable             = true;
      "whatsapp-electron".enable = true;
      "youtube-music".enable    = true;
      # steam.enable = true;

      thunderbird.enable        = true;
      thunderbird.email         = me.email;
      thunderbird.username      = user;
    };
    services = {
      ssh = {
        enable = true;
        matchBlocks = {
          "server" = {
            host = "192.168.191.168";
            user = "seanc";
            identityFile = "~/.ssh/id_ed25519";
            extraOptions.KexAlgorithms = "curve25519-sha256";
            serverAliveCountMax = 5;
            serverAliveInterval = 60;
          };
        };
      };
    };
  };
}
