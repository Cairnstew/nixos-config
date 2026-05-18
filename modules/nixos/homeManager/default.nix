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
      
      # Default programs for all hosts (minimal, rest come from profiles)
      {
        my.programs = {
          bash.enable = lib.mkDefault true;
          zsh.enable = lib.mkDefault true;
          direnv.enable = lib.mkDefault true;
          ghostty.enable = lib.mkDefault true;
          just.enable = lib.mkDefault true;
          yazi.enable = lib.mkDefault true;
        };
      }
      
      # OpenCode with MCP integration
      {
        my.programs.opencode = {
          enable = lib.mkDefault true;
          clarifai.patFile = if config.age.secrets ? "clarifai-pat" 
                              then config.age.secrets."clarifai-pat".path 
                              else null;
          deepinfra.keyFile = if config.age.secrets ? "deepinfra-key" 
                               then config.age.secrets."deepinfra-key".path 
                               else null;
          groq.keyFile = if config.age.secrets ? "groq-token" 
                          then config.age.secrets."groq-token".path 
                          else null;
          # Default to DeepInfra Kimi K2.5 when deepinfra key is available
      model = if (config.age.secrets ? "deepinfra-key")
                  then lib.mkDefault null
              else if (config.age.secrets ? "clarifai-pat")
                  then lib.mkDefault "meta-llama/Meta-Llama-3.1-8B-Instruct"
              else if (config.age.secrets ? "groq-token")
                  then lib.mkDefault "meta-llama/Meta-Llama-3.1-8B-Instruct"
              else lib.mkDefault null;
          enableMcpIntegration = lib.mkDefault true;
          
          # MCP Servers - including mcp-nixos and documentation search
          settings.mcp = lib.mkDefault {
            nixos = {
              enabled = true;
              type = "local";
              command = [ "nix" "run" "${flake.inputs.self}#mcp-nixos" ];
            };
            nixos-docs = {
              enabled = true;
              type = "local";
              command = [ "nix" "run" "${flake.inputs.self}#mcp-nixos-docs" ];
            };
          };
          
          # Custom agents with documentation awareness
          agents.nixos-unified = lib.mkDefault ''
            # NixOS Unified Expert
            
            You are an expert in NixOS Unified configurations. You have access to:
            - The mcp-nixos tool for Nix operations
            - The mcp-nixos-docs tool for searching nixos-unified.org documentation
            
            When helping with configuration:
            1. Use mcp-nixos to check flake validity and explore options
            2. Use mcp-nixos-docs to search documentation when needed
            3. Follow the AGENT.md conventions in this repository
            4. Prefer profiles (my.profiles.*) over manual module imports
            5. Keep configurations minimal and declarative
          '';
        };
      }
      
      # User-specific config from extraConfig
      cfg.extraConfig
    ];
  };
}
