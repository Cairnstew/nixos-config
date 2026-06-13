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
    ] ++ cfg.extraPackages;

    programs.gamemode.enable = lib.mkDefault cfg.gamemode.enable;

    home-manager.users.${username} = {
      home.sessionVariables =
        lib.mkIf (cfg.extraCompatPaths != null) {
          STEAM_EXTRA_COMPAT_TOOLS_PATHS = cfg.extraCompatPaths;
        };

      xdg.desktopEntries = lib.mkIf (cfg.games != { })
        (builtins.listToAttrs (lib.mapAttrsToList (name: game: {
          name = "steam_icon_${game.appId}";
          value = {
            name = if game.name != "" then game.name else name;
            noDisplay = true;
          };
        }) cfg.games));

      home.packages =
        lib.mkMerge [
          (lib.mkIf (cfg.games != { })
            (lib.mapAttrsToList (name: game:
              let
                displayName = if game.name != "" then game.name else name;
                envExports = lib.mapAttrsToList (k: v: "export ${lib.escapeShellArg k}=${lib.escapeShellArg v}") game.env;
                bin = pkgs.writeShellScriptBin "steam-game-${name}" (
                  ''
                    ${lib.concatStringsSep "\n" envExports}
                    exec ${lib.getBin pkgs.steam}/bin/steam steam://rungameid/${game.appId}
                  ''
                );
              in
              pkgs.runCommandLocal "steam-game-${name}" {} ''
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
            ) cfg.games))
          (lib.mkIf cfg.shaderPreCaching.enable (
            let
              scriptPy = pkgs.writers.writePython3 "ensure-steam-shader-cache"
                {
                  libraries = [ pkgs.python3Packages.srctools ];
                }
                ''
                  import os
                  import shutil
                  from pathlib import Path
                  from srctools import Keyvalues, AtomicWriter

                  steam_dir = Path(os.path.expanduser("~/.steam/steam"))


                  def set_keyvalues(path, root_key, keypath, pairs):
                      if not path.parent.exists():
                          path.parent.mkdir(parents=True)
                      if path.is_file():
                          with path.open(encoding="utf-8") as f:
                              kv = Keyvalues.parse(f, path)
                      else:
                          kv = Keyvalues(root_key)

                      cursor = kv
                      for key in keypath:
                          existing = list(cursor.find_all(key))
                          if existing:
                              cursor = existing[0]
                          else:
                              block = Keyvalues(key)
                              cursor.append(block)
                              cursor = block

                      modified = False
                      for k, val in pairs:
                          existing = list(cursor.find_all(k))
                          if existing:
                              if existing[0].value != val:
                                  existing[0].value = val
                                  modified = True
                          else:
                              cursor.append(Keyvalues(k, val))
                              modified = True

                      if modified:
                          with AtomicWriter(path, encoding="utf-8") as f:
                              kv.serialise(f)


                  # ── Clear Overwatch shader cache ──
                  for p in [
                      steam_dir / "steamapps" / "shadercache" / "2357570",
                      steam_dir / "steamapps" / "compatdata" / "2357570",
                  ]:
                      if p.exists():
                          shutil.rmtree(p)

                  # ── Set shader pre-caching in config.vdf ──
                  set_keyvalues(
                      steam_dir / "config" / "config.vdf",
                      "InstallConfigStore",
                      ["InstallConfigStore", "Software", "Valve", "Steam"],
                      [
                          ("ShaderPreCache", "1"),
                          ("AllowBackgroundProcessingOfVulkanShaders", "1"),
                      ],
                  )

                  # ── Also set in localconfig.vdf for each user ──
                  userdata = steam_dir / "userdata"
                  if userdata.exists():
                      for user_dir in userdata.iterdir():
                          if user_dir.is_dir() and user_dir.name.isdigit():
                              set_keyvalues(
                                  user_dir / "config" / "localconfig.vdf",
                                  "UserLocalConfigStore",
                                  ["UserLocalConfigStore", "Software", "Valve", "Steam"],
                                  [
                                      ("ShaderPreCache", "1"),
                                      ("AllowBackgroundProcessingOfVulkanShaders", "1"),
                                  ],
                              )
                '';
            in
            [ (pkgs.runCommandLocal "ensure-steam-shader-cache" { } ''
              mkdir -p $out/bin
              cp ${scriptPy} $out/bin/ensure-steam-shader-cache
            '') ]
          ))
        ];
    };
  };
}
