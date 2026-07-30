{ lib, pkgs, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.lutris = {
    enable = mkEnableOption "Lutris game manager, game library, and wine runner management";

    gamemode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Feral Gamemode for Lutris game performance optimizations.";
      };
    };

    mangohud = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Install MangoHud — a Vulkan/OpenGL overlay for monitoring FPS,
          temperatures, CPU/GPU load. Toggle in Lutris per-game with Shift+F2.
        '';
      };
    };

    gamescope = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Install Gamescope — a micro-compositor for proper fullscreen
          and resolution management on Wayland.
        '';
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for Gamescope streaming features.";
      };
    };

    battlenet = {
      enable = mkEnableOption "Battle.net desktop app via Lutris with Wine WoW64 support";

      wine = {
        package = mkOption {
          type = types.package;
          default = pkgs.wineWow64Packages.stable;
          description = "Wine package for Battle.net (use wow64 builds for best compatibility).";
        };
      };

      winetricks = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Install winetricks for managing Wine prefixes and Windows DLL dependencies.";
        };
      };

      protonup = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Install protonup-ng for managing community Wine-GE builds.
            Wine-GE often has better compatibility with Battle.net
            than upstream Wine. Run `protonup-ng` to download Wine-GE.
          '';
        };
      };

      settings = {
        esync = mkOption {
          type = types.bool;
          default = true;
          description = "Enable eventfd-based synchronization (WINEESYNC) for Battle.net.";
        };

        fsync = mkOption {
          type = types.bool;
          default = true;
          description = "Enable futex-based synchronization (WINEFSYNC, requires kernel 5.16+).";
        };

        dxvk = mkOption {
          type = types.bool;
          default = true;
          description = "Enable DXVK for DirectX 9/10/11 to Vulkan translation.";
        };

        vkd3d = mkOption {
          type = types.bool;
          default = true;
          description = "Enable VKD3D for DirectX 12 to Vulkan translation.";
        };

        overrides = mkOption {
          type = types.attrsOf types.str;
          default = { "dwrite" = "n"; };
          description = "WINEDLLOVERRIDES entries. Format: { \"dllname\" = \"n,b\"; }.";
          example = { "dwrite" = "n"; "winemenubuilder" = "e"; };
        };

        env = mkOption {
          type = types.attrsOf types.str;
          default = {
            WINEESYNC = "1";
            WINEFSYNC = "1";
            DXVK_HUD = "0";
            SDL_VIDEODRIVER = "x11";
            __GL_SHADER_DISK_CACHE = "1";
            __GL_SHADER_DISK_CACHE_SIZE = "1073741824";
          };
          description = ''
            Environment variables set when launching Battle.net.
            SDL_VIDEODRIVER=x11 forces XWayland for CEF rendering.
            This prevents invisible Battle.net windows on GNOME Wayland.
          '';
        };
      };

      gamescope = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Wrap Battle.net in Gamescope to fix invisible windows on Wayland.";
        };

        fullscreen = mkOption {
          type = types.bool;
          default = true;
          description = "Start Gamescope in fullscreen mode (-f).";
        };

        width = mkOption {
          type = types.ints.unsigned;
          default = 0;
          description = "Internal resolution width (0 = auto).";
        };

        height = mkOption {
          type = types.ints.unsigned;
          default = 0;
          description = "Internal resolution height (0 = auto).";
        };

        windowWidth = mkOption {
          type = types.ints.unsigned;
          default = 1280;
          description = "Gamescope output window width.";
        };

        windowHeight = mkOption {
          type = types.ints.unsigned;
          default = 720;
          description = "Gamescope output window height.";
        };

        refreshRate = mkOption {
          type = types.nullOr types.ints.unsigned;
          default = null;
          description = "Refresh rate limit (e.g. 60).";
        };

        extraArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Extra arguments to pass to Gamescope.";
        };
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages to install alongside Lutris.";
    };
  };
}
