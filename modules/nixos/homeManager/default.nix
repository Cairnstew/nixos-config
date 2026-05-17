{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
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
            gcloud = {
              paths = {
                # This will export GCLOUD_SERVICE_ACCOUNT_KEY_PATH pointing to the decrypted JSON path
                GCLOUD_SERVICE_ACCOUNT_KEY_PATH = config.age.secrets.gcloud-auth.path;
              };
            };
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
          clarifai.patFile = config.age.secrets."clarifai-pat".path;
          groq.keyFile = config.age.secrets."groq-token".path;
          model = "clarifai/gpt-4o";
        };
        cline = {
          enable = false;

          ollamaBaseURL = "http://${flake.config.tailnet.server.ip}:11434";

          ollamaModels = flake.config.ollamaModels;

          mcp.servers = {
            ollama = {
              type = "streamableHttp";
              url  = "http://${flake.config.tailnet.server.ip}:3100/mcp";
            };
          };

          settings = {
            "cline.maxTokens"               = 32768;
            "cline.terminalOutputLineLimit" = 500;
          };

          kanban = {
            enable    = true;
            extraArgs = [ "--port" "3000" ];
          };
        };
        aider = {
          enable = false;
          ollamaModels = flake.config.ollamaModels;
          ollamaBaseURL = "http://${flake.config.tailnet.server.ip}:11434";
          settings = {
            dark-mode = true;
            git = true;
            show-diffs = true;
          };
        };
        ghostty.enable = true;
        just.enable = true;
        obsidian = {
          repo = {
            enable = config.age.secrets ? "github-token-obsidian";
            url = "https://github.com/Cairnstew/Cairns-Notes";
            tokenFile = config.age.secrets."github-token-obsidian".path;
            
          };
        };
        yazi.enable = true;
        zsh.enable = true;
      };
    };
}
