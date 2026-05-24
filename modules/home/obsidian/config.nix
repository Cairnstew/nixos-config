{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.obsidian;
  vaultDir = "${config.home.homeDirectory}/${cfg.defaultDirectory}";
  vaultId = builtins.substring 0 16 (builtins.hashString "md5" vaultDir);
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package pkgs.jq ];

    home.file.".config/obsidian/obsidian.json" = {
      text = builtins.toJSON {
        vaults = {
          "${vaultId}" = {
            path = vaultDir;
            ts = 0;
            open = true;
          };
        };
      };
    };

    home.activation.obsidianVaultSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      VAULT_DIR="$HOME/${cfg.defaultDirectory}"

      ${lib.optionalString (cfg.repo.enable && cfg.repo.tokenFile != null) ''
        TOKEN=$(cat "${cfg.repo.tokenFile}")
        REPO_URL=$(echo "${cfg.repo.url}" | sed "s|https://|https://''${TOKEN}@|")

        if [ ! -d "$VAULT_DIR/.git" ]; then
          echo "Cloning Obsidian vault..."
          rm -rf "$VAULT_DIR" 2>/dev/null || true
          ${pkgs.git}/bin/git clone "$REPO_URL" "$VAULT_DIR"
          echo "Vault cloned successfully to $VAULT_DIR"
        fi

        if [ -d "$VAULT_DIR/.git" ]; then
          echo "Updating remote URL with token..."
          ${pkgs.git}/bin/git -C "$VAULT_DIR" remote set-url origin "$REPO_URL"

          ${pkgs.git}/bin/git -C "$VAULT_DIR" config credential.helper store
          echo "https://''${TOKEN}@github.com" > "$HOME/.git-credentials"
          chmod 600 "$HOME/.git-credentials"

          echo "Verifying remote..."
          ${pkgs.git}/bin/git -C "$VAULT_DIR" fetch \
            && echo "Token auth working" \
            || echo "WARNING: fetch failed, check token"
        else
          echo "ERROR: Vault directory exists but is not a git repo"
        fi
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
