{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  ollamaModels = flake.config.ollamaModels;
in
{

    users.users.${flake.config.me.username}.isNormalUser = lib.mkDefault true;
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules;
    home-manager.users.${flake.config.me.username}.my = { 
      programs = {
        ssh-1password.enable = true;
        bash.enable = true;
        direnv = {
          enable = true;

          secretFiles = {
            aws-cloud = {
              envFiles = [ config.age.secrets.aws-cloud.path ];  # file contains AWS_ACCESS_KEY_ID=... etc
            };
            ssh-keys = {
              paths = {
                AWS_LABS_SSH_KEY_PATH = config.age.secrets.aws-lab-ssh-key.path;
              };
            };
            #my-api = {
            #  vars = {
            #    MY_API_TOKEN = "my-api-token";  # single value secret
            #  };
            #};
          };
        };
        gh = {
          enable = config.age.secrets ? "github-token";

          tokenFile = config.age.secrets."github-token".path;

          settings = {
            git_protocol = "ssh";
          };

          hosts = {
            "github.com" = {
              user = flake.config.me.github_username;
              git_protocol = "ssh";
            };
          };
        };
        opencode = {
          enable = true;
          settings.provider.ollama = {
            npm             = "@ai-sdk/openai-compatible";
            name            = "Ollama (local)";
            options.baseURL = "http://${flake.config.tailnet.server.ip}:11434/v1";
            models          = lib.mapAttrs (_id: m: { name = m.name; }) flake.config.ollamaModels;
          };
        };
        ghostty.enable = true;
        just.enable = true;
        obsidian = {
          repo = {
            enable = config.age.secrets ? "github-token-obsidian";
            url = "https://github.com/Cairnstew/Cairns-Notes";
            tokenFile = config.age.secrets."github-token-obsidian".path;
            electron = pkgs.electron_35;
          };
        };
        yazi.enable = true;
        zsh.enable = true;
      };
    };
}
