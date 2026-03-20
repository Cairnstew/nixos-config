{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.obsidian;
in
{
  options.my.programs.obsidian = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Obsidian with custom configuration";
    };

    defaultDirectory = lib.mkOption {
      type = lib.types.str;
      default = "Documents/Obsidian_Vault";
      description = "Default vault directory relative to HOME";
    };

    repo = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Clone the Obsidian vault from a git repo on first setup";
      };

      url = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "GitHub repo URL (e.g. https://github.com/user/vault)";
      };

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to agenix-managed file containing a GitHub access token";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.obsidian = {
      enable = true;
      vaults."main-vault" = {
        enable = true;
        target = cfg.defaultDirectory;
        settings = {
          app = {
            promptDelete = false;
            alwaysUpdateLinks = true;
            attachmentFolderPath = "Media";
          };
          appearance.cssTheme = "AnuPpuccin";
        };
      };
    };

    home.activation.obsidianVaultSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
      VAULT_DIR="$HOME/${cfg.defaultDirectory}"

      ${lib.optionalString (cfg.repo.enable && cfg.repo.tokenFile != null) ''
        TOKEN=$(cat "${cfg.repo.tokenFile}")
        REPO_URL=$(echo "${cfg.repo.url}" | sed "s|https://|https://''${TOKEN}@|")

        if [ ! -d "$VAULT_DIR" ]; then
          echo "Cloning Obsidian vault..."
          ${pkgs.git}/bin/git clone "$REPO_URL" "$VAULT_DIR"
          echo "Vault cloned successfully to $VAULT_DIR"
        fi

        # Always ensure the remote is using the token, even if vault already existed
        echo "Updating remote URL with token..."
        ${pkgs.git}/bin/git -C "$VAULT_DIR" remote set-url origin "$REPO_URL"

        # Store credentials for obsidian-git push/pull
        ${pkgs.git}/bin/git -C "$VAULT_DIR" config credential.helper store
        echo "https://''${TOKEN}@github.com" > "$HOME/.git-credentials"
        chmod 600 "$HOME/.git-credentials"

        echo "Verifying remote..."
        ${pkgs.git}/bin/git -C "$VAULT_DIR" fetch && echo "Token auth working" || echo "WARNING: fetch failed, check token"
      ''}

      ${lib.optionalString cfg.repo.enable ''
        if [ -z "${cfg.repo.url}" ]; then
          echo "WARNING: obsidian.repo.enable is true but no URL was provided"
        fi
      ''}

      ${lib.optionalString (!cfg.repo.enable) ''
        if [ ! -d "$VAULT_DIR" ]; then
          echo "WARNING: Obsidian vault not found at $VAULT_DIR"
          echo "Clone your vault repo there before opening Obsidian"
        fi
      ''}
    '';
  };
}