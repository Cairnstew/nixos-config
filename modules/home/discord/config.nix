{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.discord;
  isTui = cfg.tui.enable;
  resolvedPackage = if isTui then pkgs.endcord else cfg.package;
  enabledProfiles = lib.filterAttrs (_: p: p.enable && p.tokenFile != null) cfg.tui.profile;
in
{
  config = lib.mkIf cfg.enable {
    home = {
      packages = [ resolvedPackage ] ++ cfg.extraPackages;

      sessionVariables = lib.mkIf (!isTui) {
        DISCORD_THEME = cfg.theme;
      };

      file = lib.mkIf cfg.autostart {
        ".config/autostart/discord.desktop".text =
          let
            appName = if isTui then "Endcord" else "Discord";
            execPath = "${resolvedPackage}/bin/${if isTui then "endcord" else "Discord"}";
            comment = if isTui then "Start Endcord TUI on login" else "Start Discord on login";
          in
          ''
            [Desktop Entry]
            Type=Application
            Name=${appName}
            Exec=${execPath}
            X-GNOME-Autostart-enabled=true
            NoDisplay=false
            Comment=${comment}
          '';
      };

      activation.setupEndcordToken = lib.mkIf (isTui && enabledProfiles != { }) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ENDCORD_DIR="$HOME/.config/endcord"
        PROFILES_FILE="$ENDCORD_DIR/profiles.json"
        mkdir -p "$ENDCORD_DIR"

        PROFILE_NAMES="${lib.concatStringsSep " " (builtins.attrNames enabledProfiles)}"
        FIRST_NAME="$(echo "$PROFILE_NAMES" | cut -d' ' -f1)"
        TOTAL=$({ echo "$PROFILE_NAMES" | wc -w; } 2>/dev/null)

        TEMP_FILE=$(mktemp)
        trap "rm -f $TEMP_FILE" EXIT

        echo '{' > "$TEMP_FILE"
        echo '  "selected": "'$FIRST_NAME'",' >> "$TEMP_FILE"
        echo '  "profiles": [' >> "$TEMP_FILE"

        FIRST=1
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: p: ''
          TOKEN=$(cat "${p.tokenFile}" | tr -d '\n')
          if [ -n "$TOKEN" ]; then
            if [ "$FIRST" -eq 0 ]; then
              echo ',' >> "$TEMP_FILE"
            fi
            echo '{"name":"${name}","time":null,"token":"'"$TOKEN"'","source":"plaintext"}' >> "$TEMP_FILE"
            FIRST=0
          fi
        '') enabledProfiles)}

        printf '\n' >> "$TEMP_FILE"
        echo '  ]' >> "$TEMP_FILE"
        echo '}' >> "$TEMP_FILE"

        mv "$TEMP_FILE" "$PROFILES_FILE"
        chmod 600 "$PROFILES_FILE"
        echo "[discord] Endcord profiles.json initialized with $TOTAL profile(s)"
      '');
    };
  };
}
