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

          # MCP Servers - using uvx for direct PyPI installation
          mcp = lib.mkDefault {
            nixos = {
              enabled = true;
              type = "local";
              command = [ "uvx" "mcp-nixos" ];
            };
            nixos-docs = {
              enabled = true;
              type = "local";
              command = [ "uvx" "--from" "mcp-nixos" "mcp-nixos-docs" ];
            };
          };
          
          # Structured agents configuration
          agents = {
            plan = {
              model = "opencode-go/qwen3.5-plus";
              mode = "primary";
              temperature = 0.1;
              steps = 10;
              permission = {
                edit = "deny";
                bash = "deny";
              };
            };
            explore = {
              model = "opencode-go/kimi-k2.5";
              mode = "subagent";
              temperature = 0.1;
              permission = {
                edit = "deny";
                bash = "deny";
              };
            };
            build = {
              model = "opencode-go/kimi-k2.5";
              mode = "primary";
              permission = {
                edit = "allow";
                bash = "allow";
              };
            };
          };
        };
      }
      
      # User-specific config from extraConfig
      cfg.extraConfig
    ];
  };
}
