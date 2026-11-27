{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.steam;
  inherit (flake.config.me) username;
in
{
  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = lib.mkDefault cfg.remotePlay.openFirewall;
      dedicatedServer.openFirewall = lib.mkDefault cfg.dedicatedServer.openFirewall;
    };

    environment.systemPackages = with pkgs; [
      steam-run
      steamcmd
    ] ++ cfg.extraPackages
    ++ lib.optional (lib.any (g: g.gamescope.enable) (lib.attrValues cfg.games)) pkgs.gamescope;

    programs.gamemode.enable = lib.mkDefault cfg.gamemode.enable;

    # ── Hyprland window rules ────────────────────────────────────────────
    # Inject Steam game monitor rules into Hyprland's extraWindowRules (Lua
    # hl.window_rule statements). Per-game rules are listed after the
    # catch-all so they take precedence.
    my.desktop.hyprland.core.extraWindowRules = lib.mkIf cfg.hyprland.enable (
      let
        catchAll = lib.optional (cfg.hyprland.forceMonitor != null)
          ''hl.window_rule({ match = { class = "^(steam_app_.*)$" }, monitor = "${cfg.hyprland.forceMonitor}" })'';
        perGame = lib.flatten (lib.mapAttrsToList
          (name: game:
            lib.optional (game.monitor != null) (
              let
                windowClass = if game.windowClass != null then game.windowClass else "steam_app_${game.appId}";
              in
              ''hl.window_rule({ match = { class = "^(${windowClass})$" }, monitor = "${game.monitor}" })''
            )
          )
          cfg.games);
      in
      catchAll ++ perGame
    );

    home-manager.users.${username} = {
      home.sessionVariables =
        lib.mkIf (cfg.extraCompatPaths != null) {
          STEAM_EXTRA_COMPAT_TOOLS_PATHS = cfg.extraCompatPaths;
        };

      xdg.desktopEntries = lib.mkIf (cfg.games != { })
        (builtins.listToAttrs (lib.mapAttrsToList
          (name: game: {
            name = "steam_icon_${game.appId}";
            value = {
              name = if game.name != "" then game.name else name;
              noDisplay = true;
            };
          })
          cfg.games));

      home.packages =
        lib.mkMerge [
          (lib.mkIf (cfg.games != { })
            (lib.mapAttrsToList
              (name: game:
                let
                  displayName = if game.name != "" then game.name else name;
                  envExports = lib.mapAttrsToList (k: v: "export ${lib.escapeShellArg k}=${lib.escapeShellArg v}") game.env;

                  gamescopeArgs = lib.optionals game.gamescope.enable (
                    (lib.optional (game.gamescope.width > 0) "-W ${toString game.gamescope.width}")
                    ++ (lib.optional (game.gamescope.height > 0) "-H ${toString game.gamescope.height}")
                    ++ (lib.optional (game.gamescope.refreshRate != null) "-r ${toString game.gamescope.refreshRate}")
                    ++ (lib.optional game.gamescope.fullscreen "-f")
                    ++ (lib.optional game.gamescope.adaptiveSync "-a")
                    ++ game.gamescope.extraArgs
                  );

                  bin = pkgs.writeShellScriptBin "steam-game-${name}" (
                    if game.gamescope.enable then
                      ''
                        ${lib.concatStringsSep "\n" envExports}
                        exec ${pkgs.gamescope}/bin/gamescope ${lib.concatStringsSep " " gamescopeArgs} -- ${lib.getBin pkgs.steam}/bin/steam steam://rungameid/${game.appId}
                      ''
                    else
                      ''
                        ${lib.concatStringsSep "\n" envExports}
                        exec ${lib.getBin pkgs.steam}/bin/steam steam://rungameid/${game.appId}
                      ''
                  );
                in
                pkgs.runCommandLocal "steam-game-${name}" { } ''
                  mkdir -p $out/bin $out/share/applications
                  cp ${bin}/bin/steam-game-${name} $out/bin/steam-game-${name}
                  echo "[Desktop Entry]" > $out/share/applications/steam-game-${name}.desktop
                  echo "Type=Application" >> $out/share/applications/steam-game-${name}.desktop
                  echo "Name=${displayName}" >> $out/share/applications/steam-game-${name}.desktop
                  echo "Exec=steam-game-${name}" >> $out/share/applications/steam-game-${name}.desktop
                  echo "Icon=steam" >> $out/share/applications/steam-game-${name}.desktop
                  echo "Categories=Game;" >> $out/share/applications/steam-game-${name}.desktop
                  echo "Comment=Launch ${displayName} via Steam" >> $out/share/applications/steam-game-${name}.desktop
                ''
              )
              cfg.games))
          (lib.mkIf (cfg.shaderPreCaching.enable != null) (
            let
              state = if cfg.shaderPreCaching.enable then "on" else "off";
            in
            [
              (pkgs.writeShellScriptBin "ensure-steam-shader-cache" ''
                export SHADER_PRECACHE_STATE=${state}
                ${lib.optionalString (cfg.shaderPreCaching.backgroundThreads != null)
                  "export SHADER_PRECACHE_THREADS=${toString cfg.shaderPreCaching.backgroundThreads}"}
                exec ${pkgs.python3}/bin/python3 ${./ensure-steam-shader-cache.py} "$@"
              '')
            ]
          ))
          [
            (pkgs.writeShellScriptBin "steam-clear-shader-cache" ''
              exec ${pkgs.python3}/bin/python3 ${./steam-clear-shader-cache.py} "$@"
            '')
          ]
        ];
    };
  };
}
