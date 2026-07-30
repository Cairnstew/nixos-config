{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.steam = {
    enable = mkEnableOption "Steam gaming platform with 32-bit support and gaming tools";

    remotePlay = {
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for Steam Remote Play Together.";
      };
    };

    dedicatedServer = {
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for Steam Dedicated Servers.";
      };
    };

    gamemode = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Feral Gamemode for game performance optimizations.";
      };
    };

    shaderPreCaching = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Ensure Steam shader pre-caching is enabled in config.vdf.
          Enables both "Shader Pre-Caching" and "Background Processing of
          Vulkan Shaders" in Steam → Settings → Downloads.
        '';
      };

      backgroundThreads = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 8;
        description = ''
          Number of CPU threads to use for Vulkan shader background processing.
          Writes <filename>steam_dev.cfg</filename> with
          <literal>unShaderBackgroundProcessingThreads</literal> and
          <literal>@ShaderBackgroundProcessingThreads</literal>.
          Set to your CPU thread count (e.g. 8 for a 4-core/8-thread CPU).
          When <literal>null</literal>, the script auto-detects via
          <literal>os.cpu_count()</literal>.
        '';
      };
    };

    extraCompatPaths = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Extra compatibility tool paths for Steam Proton.
        Example: "$HOME/.steam/root/compatibilitytools.d"
      '';
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra Steam-related packages to install system-wide.";
    };

    hyprland = {
      enable = mkEnableOption "Hyprland window rule integration for Steam games, forcing them onto a specific monitor";

      forceMonitor = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "DP-1";
        description = ''
          Fallback monitor to force all Steam game windows onto (e.g. "DP-1").
          Generates a windowrule matching <literal>steam_app_.*</literal> for any
          Steam game process not explicitly configured via
          <literal>my.programs.steam.games.&lt;name&gt;.monitor</literal>.
          Per-game <literal>monitor</literal> settings override this value.
          Only applies when <literal>hyprland.enable</literal> is true.
        '';
      };
    };

    games = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          appId = mkOption {
            type = types.str;
            description = "Steam App ID of the game. Find this from the Steam store URL or ProtonDB.";
          };

          name = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable name shown in GNOME/application menu. Defaults to the attribute name.";
          };

          env = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Environment variables to set when launching the game.
              These are exported before launching via steam://rungameid/.
              Common variables: PROTON_USE_WINED3D, PROTON_NO_ESYNC, WINEDLLOVERRIDES.
            '';
            example = {
              PROTON_USE_WINED3D = "1";
              WINEDLLOVERRIDES = "d3dcompiler_47=n,b";
            };
          };

          monitor = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "DP-1";
            description = ''
              Hyprland monitor to force this game window onto (e.g. "DP-1").
              Overrides <literal>my.programs.steam.hyprland.forceMonitor</literal>
              when set. Only applies when
              <literal>my.programs.steam.hyprland.enable</literal> is true.
            '';
          };

          windowClass = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "steam_app_2357570";
            description = ''
              Hyprland window class name for this game. Defaults to
              <literal>steam_app_&lt;appId&gt;</literal> which works for most
              native Steam games. Some games (especially non-Steam games added
              to Steam, or games using custom launchers) use a different class.
              Use <literal>hyprctl clients</literal> to discover the correct class.
            '';
          };

          gamescope = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Wrap the game in Gamescope for proper fullscreen on Wayland compositors.";
            };

            width = mkOption {
              type = types.ints.unsigned;
              default = 0;
              description = "Internal resolution width for Gamescope.";
            };

            height = mkOption {
              type = types.ints.unsigned;
              default = 0;
              description = "Internal resolution height for Gamescope.";
            };

            refreshRate = mkOption {
              type = types.nullOr types.ints.unsigned;
              default = null;
              description = "Refresh rate limit for Gamescope (e.g. 144).";
            };

            fullscreen = mkOption {
              type = types.bool;
              default = true;
              description = "Start in fullscreen mode (-f).";
            };

            adaptiveSync = mkOption {
              type = types.bool;
              default = false;
              description = "Enable adaptive sync / VRR (-a).";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Extra arguments to pass to Gamescope.";
            };
          };
        };
      });
      default = { };
      example = {
        "elden-ring" = {
          appId = "1245620";
          env.PROTON_USE_WINED3D = "1";
        };
      };
      description = ''
        Per-game Steam launch configurations.
        Each entry creates a <filename>steam-game-&lt;name&gt;</filename> wrapper script
        in the user's PATH that sets the specified environment variables and launches
        the game via <literal>steam://rungameid/&lt;appId&gt;</literal>.
      '';
    };
  };
}
