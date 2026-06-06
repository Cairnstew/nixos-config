{ config, lib, pkgs, flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  inherit (flake.config.me) username;
  cfg = config.my.homeManager;
  mcpServers = self.packages.${pkgs.system};

  betterEmailPkg =
    pkgs.writeShellApplication {
      name = "better-email";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        EMAIL_APP_PASSWORD=$(cat ${config.age.secrets.mcp-better-email-password.path})
        export EMAIL_APP_PASSWORD
        exec npx -y @n24q02m/better-email-mcp "$@"
      '';
      meta.description = "MCP server: better-email (IMAP/SMTP for AI agents)";
    };
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf cfg.enable {
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules;

    age.secrets = {
      mcp-better-email-password = { owner = lib.mkForce username; group = lib.mkForce "users"; };
      clarifai-pat = { owner = lib.mkForce username; };
      deepinfra-key = { owner = lib.mkForce username; };
      opencode-token = { owner = lib.mkForce username; };
      groq-token = { owner = lib.mkForce username; };
      github-token = { owner = lib.mkForce username; group = lib.mkForce "users"; };
    };

    users.users.${username}.isNormalUser = lib.mkDefault true;

    home-manager.users.${username} = lib.mkMerge [
      {
        home.stateVersion = lib.mkDefault "26.05";
        systemd.user.startServices = lib.mkDefault "sd-switch";
        imports = cfg.extraModules;
      }

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

      {
        my.programs.opencode = {
          enable = lib.mkDefault true;
          enableLsp = lib.mkDefault true;
          clarifai.patFile = config.age.secrets.clarifai-pat.path;
          deepinfra.keyFile = config.age.secrets.deepinfra-key.path;
          opencode-go.keyFile = config.age.secrets.opencode-token.path;
          groq.keyFile = config.age.secrets.groq-token.path;

          model = lib.mkDefault null;
          enableMcpIntegration = lib.mkDefault true;

          extraPackages = with pkgs; with mcpServers; [
            mcp-nixos
            mcp-server-fetch
            mcp-server-sqlite
            betterEmailPkg
            terraform
            nixpkgs-fmt
          ];

          # Host-specific: better-email MCP references agenix secret and flake identity
          # Uses mkDefault so it merges with home module's MCP defaults (nixos, fetch, sqlite)
          # at the same priority — host configs can still override with a direct assignment.
          mcp = lib.mkDefault {
            better-email = {
              enabled = true;
              type = "local";
              command = [ "better-email" ];
              environment = {
                EMAIL_PROVIDER = "gmail";
                EMAIL_USER = flake.config.me.email;
              };
              timeout = 30000;
            };
          };
        };
      }

      cfg.extraConfig
    ];
  };
}
