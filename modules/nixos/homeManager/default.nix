# modules/nixos/homeManager/default.nix
# Home Manager integration for NixOS hosts
# Automatically applies home profiles based on system configuration
{ flake, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  inherit (flake.config.me) username;
  
  cfg = config.my.homeManager;
in
{
  imports = [
    # Home Manager NixOS module
    inputs.home-manager.nixosModules.home-manager
  ];

  options.my.homeManager = {
    enable = lib.mkEnableOption "Home Manager integration" // { default = true; };
    
    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [];
      description = "Extra home-manager modules to import for this user.";
    };
    
    extraConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Extra configuration to merge into the user's home config.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Basic home-manager setup
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules;
    
    # Configure the primary user
    users.users.${username}.isNormalUser = lib.mkDefault true;
    
    # Apply home configuration
    home-manager.users.${username} = lib.mkMerge [
      # Base configuration
      {
        home.stateVersion = lib.mkDefault "24.05";
        
        # Import all home modules
        imports = cfg.extraModules;
      }
      
      # User-specific config from extraConfig
      cfg.extraConfig
    ];
  };
}
