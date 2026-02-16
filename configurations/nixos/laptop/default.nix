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
  };

  # ── System services ────────────────────────────────────
  my.services = {
    zerotier = {
      enable   = true;
      networks = [ me.zerotier_network ];
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
  home-manager.users.${user}.my = {
    programs = {
      cudatext.enable           = true;
      discord.enable            = true;
      firefox.enable            = true;
      gh.hosts."github.com" = {
          user = "Cairnstew";
          git_protocol = "ssh";
        };
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
  };
}
