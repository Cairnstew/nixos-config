{ config, lib, pkgs, flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  inherit (flake.config.me) username;
  cfg = config.my.homeManager;
  sec = config.my.secrets;
  mcpServers = self.packages.${pkgs.system};

  # Helper: check if a catalog secret exists and is available
  hasSecret = path: sec.enable && (sec.catalog ? ${path})
    && builtins.hasAttr (sec.catalog.${path}.name) config.age.secrets;

  # Get secret name from catalog
  secretName = path: sec.catalog.${path}.name or null;

  # Better Email MCP — conditional on agenix secret
  hasEmailSecret = hasSecret "mcp.better-email.password";
  betterEmailSecretName = secretName "mcp.better-email.password";
  betterEmailPkg =
    if hasEmailSecret then
      pkgs.writeShellApplication
        {
          name = "better-email";
          runtimeInputs = [ pkgs.nodejs ];
          text = ''
            EMAIL_APP_PASSWORD=$(cat ${config.age.secrets.${betterEmailSecretName}.path})
            export EMAIL_APP_PASSWORD
            exec npx -y @n24q02m/better-email-mcp "$@"
          '';
          meta.description = "MCP server: better-email (IMAP/SMTP for AI agents)";
        }
    else null;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf cfg.enable {
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules;

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
          clarifai.patFile =
            if hasSecret "ai.clarifai.pat"
            then config.age.secrets.${secretName "ai.clarifai.pat"}.path
            else null;
          deepinfra.keyFile =
            if hasSecret "ai.deepinfra.key"
            then config.age.secrets.${secretName "ai.deepinfra.key"}.path
            else null;
          opencode-go.keyFile =
            if hasSecret "ai.opencode.token"
            then config.age.secrets.${secretName "ai.opencode.token"}.path
            else null;
          groq.keyFile =
            if hasSecret "ai.groq.token"
            then config.age.secrets.${secretName "ai.groq.token"}.path
            else null;

          model =
            if (hasSecret "ai.deepinfra.key")
            then lib.mkDefault null
            else if (hasSecret "ai.clarifai.pat")
            then lib.mkDefault "meta-llama/Meta-Llama-3.1-8B-Instruct"
            else if (hasSecret "ai.groq.token")
            then lib.mkDefault "meta-llama/Meta-Llama-3.1-8B-Instruct"
            else lib.mkDefault null;
          enableMcpIntegration = lib.mkDefault true;

          extraPackages = with mcpServers; [
            mcp-nixos
            mcp-server-fetch
            mcp-server-git
            mcp-server-sqlite
          ] ++ lib.optional hasEmailSecret betterEmailPkg;

          mcp = lib.mkDefault ({
            nixos = {
              enabled = true;
              type = "local";
              command = [ "mcp-nixos" ];
              timeout = 120000;
            };
            fetch = {
              enabled = true;
              type = "local";
              command = [ "mcp-server-fetch" ];
              timeout = 30000;
            };
            git = {
              enabled = true;
              type = "local";
              command = [ "mcp-server-git" "--repository" "/home/seanc/nixos-config" ];
              timeout = 30000;
            };
            sqlite = {
              enabled = true;
              type = "local";
              command = [ "mcp-server-sqlite" ];
              timeout = 30000;
            };
          } // lib.optionalAttrs hasEmailSecret {
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
          });

          skills = {
            git-repo-management = lib.mkDefault (builtins.readFile ../../home/opencode/skills/git-repo-management.md);
            nixos-configuration = lib.mkDefault (builtins.readFile ../../home/opencode/skills/nixos-configuration.md);
            module-development = lib.mkDefault (builtins.readFile ../../home/opencode/skills/module-development.md);
          };
        };
      }

      {
        my.programs.opencode.agents = {
          plan = {
            model = "opencode-go/deepseek-v4-flash";
            mode = "primary";
            temperature = 0.1;
            steps = 10;
            permission = { edit = "deny"; bash = "deny"; };
          };
          explore = {
            model = "opencode-go/deepseek-v4-flash";
            mode = "subagent";
            temperature = 0.1;
            permission = { edit = "deny"; bash = "deny"; };
          };
          build = {
            model = "opencode-go/deepseek-v4-flash";
            mode = "primary";
            permission = { edit = "allow"; bash = "allow"; };
          };
        };
      }

      cfg.extraConfig
    ];
  };
}
