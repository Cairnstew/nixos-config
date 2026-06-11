# modules/nixos/profiles/home/default.nix
# Home-level profiles that configure user programs
{ lib, config, flake, ... }:
let
  cfg = config.my.homeProfiles;
  inherit (flake.config.me) username;
in
{
  imports = [
    ./common.nix
    ./development.nix
    ./desktop.nix
    ./minimal.nix
  ];

  # Home profiles configure home-manager programs
  options.my.homeProfiles = {
    common.enable = lib.mkEnableOption "common home profile (shell, basic tools)";
    desktop.enable = lib.mkEnableOption "desktop home profile (GUI apps)";
    development.enable = lib.mkEnableOption "development home profile (dev tools)";
    minimal.enable = lib.mkEnableOption "minimal home profile (essential only)";
    server.enable = lib.mkEnableOption "server home profile (SSH tools)";
  };

  # Apply home profiles to the user's home-manager configuration
  # This only works when home-manager is enabled for the user
  config.home-manager.users.${username}.my.programs = lib.mkIf config.my.homeManager.enable (lib.mkMerge [
    # Common profile
    (lib.mkIf cfg.common.enable {
      bash.enable = lib.mkDefault true;
      zsh.enable = lib.mkDefault true;
      direnv.enable = lib.mkDefault true;
      gh.enable = lib.mkDefault true;
      ghostty.enable = lib.mkDefault true;
      just.enable = lib.mkDefault true;
      yazi.enable = lib.mkDefault true;
    })

    # Desktop profile
    (lib.mkIf cfg.desktop.enable {
      discord.enable = lib.mkDefault true;
      firefox = {
        enable = lib.mkDefault true;
        extensions = lib.mkDefault [ "ublock-origin" "1password" ];
      };
      obsidian.enable = lib.mkDefault true;
      thunderbird.enable = lib.mkDefault true;
      thunderbird.email = lib.mkDefault flake.config.me.email;
      thunderbird.username = lib.mkDefault username;
      vscode.enable = lib.mkDefault true;
    })

    # Development profile
    (lib.mkIf cfg.development.enable {
      cudatext.enable = lib.mkDefault true;
      vscode.enable = lib.mkDefault true;
      obsidian.enable = lib.mkDefault true;
      "zed-editor".enable = lib.mkDefault true;
    })

    # Server profile (minimal GUI)
    (lib.mkIf cfg.server.enable {
      # Minimal GUI apps for server
      firefox.enable = lib.mkDefault false;
      vscode.enable = lib.mkDefault true; # May want to edit configs
    })

    # Minimal profile
    (lib.mkIf cfg.minimal.enable {
      bash.enable = lib.mkDefault true;
      # Everything else disabled
    })
  ]);
}
