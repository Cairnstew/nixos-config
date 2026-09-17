# modules/home/balatro/config.nix
# Balatro game with optional multiplayer mod support.
# The multiplayer launcher is an Electron AppImage wrapped with buildFHSEnv
# for NixOS compatibility. The mod files are deployed to the game's Mods
# directory via a home-manager activation script.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.balatro;

  # ── Pinned versions & hashes ────────────────────────────────────────────
  launcherVersion = cfg.multiplayer.launcher.version;
  modVersion = cfg.multiplayer.mod.version;

  launcherSrc = pkgs.fetchurl {
    url = "https://github.com/Balatro-Multiplayer/Balatro-Multiplayer-Launcher/releases/download/v${launcherVersion}/balatro-multiplayer-launcher.AppImage";
    # Update hash on version bump: nix build .#nixosConfigurations.<host>.config.system.build.toplevel
    # then replace with the hash from the error message.
    hash = "sha256-LWm+XhwjQIYAtlbax/PqJMgIsomiZkT8KYrN0jMzG8Y=";
  };

  modSrc = pkgs.fetchzip {
    url = "https://github.com/Balatro-Multiplayer/BalatroMultiplayer/releases/download/v${modVersion}/BalatroMultiplayer.zip";
    # Update hash on version bump.
    hash = "sha256-tUMoby0Yi9L5m8fIsyX5jQmljBOziQTbFuQh3/iCHvo=";
    stripRoot = false;
  };

  # ── FHS-wrapped launcher ────────────────────────────────────────────────
  # appimageTools handles extraction and FHS wrapping for AppImages on NixOS.
  launcher = pkgs.appimageTools.wrapType2 {
    name = "balatro-multiplayer-launcher";
    pname = "balatro-multiplayer-launcher";
    version = launcherVersion;
    src = launcherSrc;

    extraPkgs = pkgs: [
      pkgs.zlib
      pkgs.stdenv.cc.cc.lib
      pkgs.nss
      pkgs.nspr
      pkgs.atk
      pkgs.at-spi2-atk
      pkgs.cups
      pkgs.libdrm
      pkgs.gtk3
      pkgs.pango
      pkgs.cairo
      pkgs.libX11
      pkgs.libXcomposite
      pkgs.libXdamage
      pkgs.libXext
      pkgs.libXfixes
      pkgs.libXrandr
      pkgs.libgbm
      pkgs.mesa
      pkgs.expat
      pkgs.fontconfig
      pkgs.freetype
      pkgs.dbus
      pkgs.libsecret
      pkgs.alsa-lib
    ];
  };

  # ── Helper: find the Balatro install dir across common Steam layouts ─────
  findBalatroDir = pkgs.writeShellScriptBin "balatro-find-install" ''
    # Common Steam library paths
    for dir in \
      "$HOME/.local/share/Steam/steamapps/common/Balatro" \
      "$HOME/.steam/steam/steamapps/common/Balatro" \
      "$HOME/.local/share/Steam/steamapps/common/balatro" \
      "$HOME/Steam/steamapps/common/Balatro" \
      "$HOME/.steam/root/steamapps/common/Balatro"; do
      if [ -d "$dir" ]; then
        echo "$dir"
        exit 0
      fi
    done

    # Search additional library folders from libraryfolders.vdf
    VDF="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
    if [ -f "$VDF" ]; then
      while IFS= read -r path; do
        cleaned=$(echo "$path" | tr -d '"' | sed 's/.*path[[:space:]]*//')
        cleaned=$(eval echo "$cleaned")
        if [ -d "$cleaned/steamapps/common/Balatro" ]; then
          echo "$cleaned/steamapps/common/Balatro"
          exit 0
        fi
      done < <(grep -oP '"path"\s+"[^"]*"' "$VDF" 2>/dev/null)
    fi

    echo "Balatro not found. Install it via Steam first." >&2
    exit 1
  '';

  # ── Install mod files into the game directory ────────────────────────────
  installMod = pkgs.writeShellScriptBin "balatro-mp-install" ''
    set -euo pipefail

    GAME_DIR=$(balatro-find-install)
    MODS_DIR="$GAME_DIR/Mods"
    mkdir -p "$MODS_DIR"

    echo "Installing Balatro Multiplayer mod v${modVersion}..."
    echo "  Game dir: $GAME_DIR"

    # Copy mod files (flat contents from zip — creates Mods/BalatroMultiplayer/)
    mkdir -p "$MODS_DIR/BalatroMultiplayer"
    cp -r ${modSrc}/* "$MODS_DIR/BalatroMultiplayer/"

    echo "Done. Balatro Multiplayer mod installed to:"
    echo "  $MODS_DIR/BalatroMultiplayer"
    echo ""
    echo "Launch via Steam (vanilla) or run 'balatro-mp-launcher' for multiplayer."
  '';

  # ── Launch wrapper: run the multiplayer launcher ──────────────────────────
  launchWrapper = pkgs.writeShellScriptBin "balatro-mp" ''
        # Detect Balatro install path
        GAME_DIR=""
        for dir in \
          "$HOME/.local/share/Steam/steamapps/common/Balatro" \
          "$HOME/.steam/steam/steamapps/common/Balatro" \
          "$HOME/.local/share/Steam/steamapps/common/balatro" \
          "$HOME/Steam/steamapps/common/Balatro" \
          "$HOME/.steam/root/steamapps/common/Balatro"; do
          if [ -d "$dir" ]; then
            GAME_DIR="$dir"
            break
          fi
        done

        # Search additional Steam library folders
        if [ -z "$GAME_DIR" ]; then
          VDF="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
          if [ -f "$VDF" ]; then
            while IFS= read -r path; do
              cleaned=$(echo "$path" | tr -d '"' | sed 's/.*path[[:space:]]*//')
              cleaned=$(eval echo "$cleaned")
              if [ -d "$cleaned/steamapps/common/Balatro" ]; then
                GAME_DIR="$cleaned/steamapps/common/Balatro"
                break
              fi
            done < <(grep -oP '"path"\s+"[^"]*"' "$VDF" 2>/dev/null)
          fi
        fi

        # Write game path to launcher settings
        if [ -n "$GAME_DIR" ]; then
          SETTINGS="$HOME/.config/Balatro Multiplayer Launcher/settings.json"
          if [ -f "$SETTINGS" ]; then
            # Update settings.json with the game directory
            TMP=$(mktemp)
            ${pkgs.python3}/bin/python3 -c "
    import json, sys
    with open('$SETTINGS') as f:
        settings = json.load(f)
    settings['gameDirectory'] = '$GAME_DIR'
    settings['linuxModsDirectory'] = '$GAME_DIR/Mods'
    settings['onboardingCompleted'] = True
    with open('$TMP', 'w') as f:
        json.dump(settings, f, indent=2)
    "
            mv "$TMP" "$SETTINGS"
          fi
        fi

        exec balatro-multiplayer-launcher "$@"
  '';

in
{
  config = lib.mkIf cfg.enable {
    home.packages = lib.mkMerge [
      # Always: helper scripts when balatro is enabled
      (lib.mkIf cfg.enable [
        findBalatroDir
      ])

      # Multiplayer: launcher, installer, and launch wrapper
      (lib.mkIf cfg.multiplayer.enable [
        launcher
        installMod
        launchWrapper
      ])
    ];

    # Install mod files on home-manager switch when multiplayer is enabled
    home.activation.installBalatroMultiplayer = lib.mkIf cfg.multiplayer.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                # Deploy Balatro Multiplayer mod files
                # This runs on every switch; the copy is idempotent.
                GAME_DIR=""
                for dir in \
                  "$HOME/.local/share/Steam/steamapps/common/Balatro" \
                  "$HOME/.steam/steam/steamapps/common/Balatro" \
                  "$HOME/.local/share/Steam/steamapps/common/balatro" \
                  "$HOME/Steam/steamapps/common/Balatro" \
                  "$HOME/.steam/root/steamapps/common/Balatro"; do
                  if [ -d "$dir" ]; then
                    GAME_DIR="$dir"
                    break
                  fi
                done

                if [ -n "$GAME_DIR" ]; then
                  MODS_DIR="$GAME_DIR/Mods"
                  mkdir -p "$MODS_DIR/BalatroMultiplayer"
                  cp -rn ${modSrc}/* "$MODS_DIR/BalatroMultiplayer/" 2>/dev/null || \
                    cp -r ${modSrc}/* "$MODS_DIR/BalatroMultiplayer/"
                fi

                # Set Steam launch options for Balatro multiplayer mod
                # Requires: WINEDLLOVERRIDES="version=n,b" %command%
                STEAM_CONFIG="$HOME/.local/share/Steam/config/config.vdf"
                if [ -f "$STEAM_CONFIG" ]; then
                  ${pkgs.python3}/bin/python3 - "$STEAM_CONFIG" << 'PYEOF'
        import sys

        STEAM_CONFIG = sys.argv[1]

        with open(STEAM_CONFIG, "r") as f:
            lines = f.readlines()

        # --- Check if apps/2379780/LaunchOptions already exists ---
        def find_section(lines, key, start=0):
            """Find a VDF section by key name, return (start_line, end_line) or None.
            Handles nested braces properly."""
            for i in range(start, len(lines)):
                stripped = lines[i].strip()
                if stripped == f'"{key}"' or stripped.startswith(f'"{key}"'):
                    if '{' in stripped:
                        depth = 0
                        for j in range(i, len(lines)):
                            depth += lines[j].count('{') - lines[j].count('}')
                            if depth == 0:
                                return (i, j)
                    elif i + 1 < len(lines) and lines[i + 1].strip() == '{':
                        depth = 0
                        for j in range(i + 1, len(lines)):
                            depth += lines[j].count('{') - lines[j].count('}')
                            if depth == 0:
                                return (i, j)
            return None

        # Find the Steam section (3 tabs deep)
        steam_section = find_section(
            lines, "Steam",
            start=next(i for i, l in enumerate(lines) if '"Software"' in l.strip())
        )
        if not steam_section:
            print("Could not find Steam section in config.vdf")
            sys.exit(1)

        steam_start, steam_end = steam_section

        # Find or create "apps" section inside Steam
        apps_section = find_section(lines, "apps", start=steam_start)

        if apps_section:
            apps_start, apps_end = apps_section
            # Find 2379780 inside apps
            app_section = find_section(lines, "2379780", start=apps_start)
            if app_section:
                app_start, app_end = app_section
                app_block = "".join(lines[app_start:app_end + 1])
                if "LaunchOptions" in app_block:
                    print("Steam launch options already set for Balatro.")
                    sys.exit(0)
                # Add LaunchOptions before closing brace of app section
                insert_line = app_end  # the closing } of "2379780"
                lines.insert(insert_line, '\t\t\t\t\t"LaunchOptions"\t\t"WINEDLLOVERRIDES=\\"version=n,b\\" %command%"\n')
                with open(STEAM_CONFIG, "w") as f:
                    f.writelines(lines)
                print("Added LaunchOptions to existing Balatro app section.")
                sys.exit(0)
            else:
                # Add 2379780 section inside apps, before apps closing brace
                insert_line = apps_end  # the closing } of "apps"
                new_lines = [
                    '\t\t\t\t"2379780"\n',
                    '\t\t\t\t{\n',
                    '\t\t\t\t\t"LaunchOptions"\t\t"WINEDLLOVERRIDES=\\"version=n,b\\" %command%"\n',
                    '\t\t\t\t}\n',
                ]
                for j, nl in enumerate(new_lines):
                    lines.insert(insert_line + j, nl)
                with open(STEAM_CONFIG, "w") as f:
                    f.writelines(lines)
                print("Created Balatro app section with LaunchOptions.")
                sys.exit(0)
        else:
            # Create apps section inside Steam, before Steam's closing brace
            insert_line = steam_end  # the closing } of "Steam"
            new_lines = [
                '\t\t\t\t"apps"\n',
                '\t\t\t\t{\n',
                '\t\t\t\t\t"2379780"\n',
                '\t\t\t\t\t{\n',
                '\t\t\t\t\t\t"LaunchOptions"\t\t"WINEDLLOVERRIDES=\\"version=n,b\\" %command%"\n',
                '\t\t\t\t\t}\n',
                '\t\t\t\t}\n',
            ]
            for j, nl in enumerate(new_lines):
                lines.insert(insert_line + j, nl)
            with open(STEAM_CONFIG, "w") as f:
                f.writelines(lines)
            print("Created apps section with Balatro LaunchOptions.")
            sys.exit(0)
        PYEOF
                fi
      ''
    );
  };
}
