{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.hearthstone;
  hsPkg = if cfg.package != null then cfg.package else flake.inputs.hearthstone-linux-gui.packages.${pkgs.stdenv.hostPlatform.system}.default;

  hsEnv = {
    WEBKIT_DISABLE_DMABUF_RENDERER = "1";
  };

  username = flake.config.me.username;
  defaultGameDir = "/home/${username}/.local/share/hearthstone-linux-gui/game";
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ hsPkg ];

    hardware.graphics.enable = lib.mkDefault true;

    systemd.tmpfiles.rules = lib.optionals (cfg.dataDir != null) [
      "d ${cfg.dataDir} 0755 ${username} users -"
    ];

    home-manager.users.${username} = {
      home.sessionVariables = hsEnv;

      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = {
        "x-scheme-handler/wtcg" = "io.github.hearthstone_linux_gui.auth-callback.desktop";
        "x-scheme-handler/blizzard-hearthstone" = "io.github.hearthstone_linux_gui.auth-callback.desktop";
        "x-scheme-handler/hearthstone-linux" = "io.github.hearthstone_linux_gui.auth-callback.desktop";
        "x-scheme-handler/hearthstone-linux-gui" = "io.github.hearthstone_linux_gui.auth-callback.desktop";
      };

      home.activation.linkHearthstoneGameDir = lib.mkIf (cfg.dataDir != null) {
        after = [ "writeBoundary" ];
        before = [ ];
        data = ''
          mkdir -p "$(dirname "${defaultGameDir}")"
          target="${cfg.dataDir}/game"
          mkdir -p "${cfg.dataDir}"

          if [ ! -e "${defaultGameDir}" ]; then
            ln -s "$target" "${defaultGameDir}"
            echo "[hearthstone] Symlinked ${defaultGameDir} → $target"
          elif [ -L "${defaultGameDir}" ]; then
            current="$(readlink "${defaultGameDir}")"
            if [ "$current" != "$target" ]; then
              rm "${defaultGameDir}"
              ln -s "$target" "${defaultGameDir}"
              echo "[hearthstone] Updated symlink: ${defaultGameDir} → $target"
            fi
          else
            echo "[hearthstone] Warning: ${defaultGameDir} exists as a real directory."
            echo "[hearthstone] To move existing data to $target:"
            echo "[hearthstone]   mkdir -p $target"
            echo "[hearthstone]   cp -a ${defaultGameDir}/. $target/"
            echo "[hearthstone]   rm -rf ${defaultGameDir}"
            echo "[hearthstone]   ln -s $target ${defaultGameDir}"
          fi
        '';
      };

      xdg.desktopEntries."io.github.hearthstone_linux_gui" = {
        name = "Hearthstone";
        exec = "${hsPkg}/bin/hearthstone-linux-gui";
        icon = "io.github.hearthstone_linux_gui";
        categories = [ "Game" ];
        comment = "Hearthstone (native Linux, no Wine)";
        terminal = false;
      };

      xdg.desktopEntries."io.github.hearthstone_linux_gui.auth-callback" = {
        name = "Hearthstone Login Callback";
        exec = "${hsPkg}/bin/hearthstone-linux-gui --auth-callback %u";
        icon = "io.github.hearthstone_linux_gui";
        categories = [ "Game" ];
        mimeType = [
          "x-scheme-handler/wtcg"
          "x-scheme-handler/blizzard-hearthstone"
          "x-scheme-handler/hearthstone-linux"
          "x-scheme-handler/hearthstone-linux-gui"
        ];
        settings.NoDisplay = "true";
        comment = "Handles Battle.net OAuth callback for Hearthstone";
        terminal = false;
      };
    };
  };
}
