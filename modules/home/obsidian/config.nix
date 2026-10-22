{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.obsidian;
  vaultDir = "${config.home.homeDirectory}/${cfg.defaultDirectory}";
  vaultId = builtins.substring 0 16 (builtins.hashString "md5" vaultDir);

  enabledPlugins = lib.filterAttrs (_: plugin: plugin.enable) cfg.plugins;

  # One fixed-output fetch per release asset. Assets are immutable per tag, so
  # the pinned hash both verifies the download and makes the install reproducible.
  fetchAsset =
    plugin: name: hash:
    pkgs.fetchurl {
      url = "https://github.com/${plugin.repo}/releases/download/${plugin.version}/${name}";
      inherit hash;
    };

  # Assemble exactly the files Obsidian loads. `data.json` is deliberately not
  # part of this derivation: it belongs to the plugin and is written at run time.
  pluginDrv = id: plugin:
    pkgs.runCommandLocal "obsidian-plugin-${id}-${plugin.version}" { } ''
      mkdir -p "$out"
      install -m 0644 ${fetchAsset plugin "main.js" plugin.mainJsHash} "$out/main.js"
      install -m 0644 ${fetchAsset plugin "manifest.json" plugin.manifestHash} "$out/manifest.json"
      ${lib.optionalString (plugin.stylesHash != null) ''
        install -m 0644 ${fetchAsset plugin "styles.css" plugin.stylesHash} "$out/styles.css"
      ''}
    '';

  plugins = lib.mapAttrs pluginDrv enabledPlugins;

  # Install one plugin, then make sure Obsidian has it enabled. Both halves are
  # idempotent: files are only rewritten when the installed version differs, and
  # community-plugins.json is only touched when the id is missing, so Obsidian
  # stays the owner of that file.
  installPlugin = id: plugin:
    let
      drv = plugins.${id};
    in
    ''
      plugin_dir="$VAULT_DIR/.obsidian/plugins/${id}"
      mkdir -p "$plugin_dir"

      installed_version="$(${pkgs.jq}/bin/jq -r '.version // empty' "$plugin_dir/manifest.json" 2>/dev/null || true)"

      if [ "$installed_version" != "${plugin.version}" ]; then
        install -m 0644 ${drv}/main.js "$plugin_dir/main.js"
        install -m 0644 ${drv}/manifest.json "$plugin_dir/manifest.json"
        ${lib.optionalString (plugin.stylesHash != null) ''
          install -m 0644 ${drv}/styles.css "$plugin_dir/styles.css"
        ''}
        echo "obsidian: installed ${id} ${plugin.version}"
      fi

      if [ -f "$plugin_dir/main.js" ] && [ -f "$plugin_dir/manifest.json" ]; then
        if [ -f "$VAULT_DIR/.obsidian/community-plugins.json" ]; then
          if ! ${pkgs.jq}/bin/jq -e --arg id "${id}" 'index($id) != null' \
                "$VAULT_DIR/.obsidian/community-plugins.json" >/dev/null 2>&1; then
            tmp="$(mktemp)"
            ${pkgs.jq}/bin/jq --arg id "${id}" '. + [$id]' \
              "$VAULT_DIR/.obsidian/community-plugins.json" > "$tmp" \
              && mv "$tmp" "$VAULT_DIR/.obsidian/community-plugins.json"
            echo "obsidian: enabled ${id}"
          fi
        else
          printf '[\n  "%s"\n]\n' "${id}" > "$VAULT_DIR/.obsidian/community-plugins.json"
          echo "obsidian: enabled ${id}"
        fi
      else
        echo "obsidian: ${id} assets missing in $plugin_dir - not enabling" >&2
      fi
    '';
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

    # Plugins install after the vault exists, so the first switch on a fresh
    # machine clones the vault and installs plugins in one pass.
    home.activation.obsidianPlugins = lib.mkIf (enabledPlugins != { }) (
      lib.hm.dag.entryAfter [ "obsidianVaultSetup" ] ''
        VAULT_DIR="$HOME/${cfg.defaultDirectory}"

        if [ ! -d "$VAULT_DIR" ]; then
          echo "obsidian: vault not found at $VAULT_DIR - skipping plugin install"
          echo "obsidian: open the vault once, then re-run home-manager switch"
        else
          mkdir -p "$VAULT_DIR/.obsidian/plugins"
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList installPlugin enabledPlugins)}
        fi
      ''
    );
  };
}
