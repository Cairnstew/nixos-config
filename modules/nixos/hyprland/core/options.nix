{ lib, ... }:
{
  options.my.desktop.hyprland.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Hyprland compositor core (programs.hyprland, env vars, hyprland.lua).";
    };

    workspaceStartup = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.str;
            example = "firefox";
            description = "Command to execute on the specified workspace.";
          };
          workspace = lib.mkOption {
            type = lib.types.str;
            example = "1";
            description = ''
              Workspace to launch on. Matches the workspace assigned to a monitor
              via my.monitors[].workspace.
            '';
          };
          class = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "firefox";
            description = ''
              Window class for applying size/position/floating rules.
              Use `hyprctl clients` to discover class names.
            '';
          };
          title = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "Mozilla Firefox";
            description = ''
              Window title regex for applying size/position/floating rules.
              Combined with class via AND logic in generated window rules.
            '';
          };
          floating = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Force the window to float. Required for custom size/position.";
          };
          size = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                width = lib.mkOption { type = lib.types.int; };
                height = lib.mkOption { type = lib.types.int; };
              };
            });
            default = null;
            example = { width = 1200; height = 800; };
            description = ''
              Window size in pixels. Implicitly forces floating regardless of
              the floating option.
            '';
          };
          position = lib.mkOption {
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                x = lib.mkOption { type = lib.types.int; };
                y = lib.mkOption { type = lib.types.int; };
              };
            });
            default = null;
            example = { x = 100; y = 50; };
            description = ''
              Window position in pixels. Implicitly forces floating regardless of
              the floating option.
            '';
          };
          silent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Don't switch focus to the workspace when launching.";
          };
        };
      });
      default = [ ];
      example = [
        {
          workspace = "1";
          command = "ghostty";
        }
        {
          workspace = "2";
          command = "firefox";
          silent = true;
        }
        {
          workspace = "3";
          command = "spotify";
          class = "Spotify";
          floating = true;
          size = { width = 1200; height = 800; };
          position = { x = 10; y = 40; };
        }
      ];
      description = ''
        Applications to launch on specific workspaces at Hyprland startup.
        Generates both exec-once commands and associated window rules.
        Use `hyprctl clients` to discover window class names and sizes.
      '';
    };

    extraExecOnce = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "foot --server" "playerctld daemon" ];
      description = ''
        Additional exec-once commands not tied to a specific workspace.
        For workspace-bound launch, use workspaceStartup instead.
      '';
    };

    extraBinds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        ''hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("firefox"))''
        ''hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("ghostty -e ssh server"))''
      ];
      description = ''
        Additional keybind lines appended to the keybinds section of
        hyprland.lua. Each entry is a complete Lua statement (usually an
        `hl.bind` call); the `mainMod` local defined at the top of the
        generated file is in scope. Use this rather than editing
        core/config.nix for a bind that belongs to one host.
      '';
    };

    extraWindowRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        ''hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true })''
        ''hl.window_rule({ match = { class = "^(firefox)$" }, tile = true })''
      ];
      description = ''
        Additional window rules appended to the window rules section of
        hyprland.lua. Each entry is a complete Lua statement (usually an
        `hl.window_rule` call), e.g.
        `hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true })`.
      '';
    };

    debug = {
      enable = lib.mkEnableOption "debug logging section in hyprland.lua (debug.disable_logs, debug.gl_debugging)";

      disableLogs = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          debug.disable_logs in hyprland.lua. Set to true to disable logging,
          false to enable. Defaults to false (logs on) to match Hyprland's own
          default. Only written to config when debug.enable is true.
        '';
      };

      glDebugging = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          debug.gl_debugging in hyprland.lua. Enables OpenGL error messages.
          Disabled by default due to performance impact. Only written to config
          when debug.enable is true.
        '';
      };

      trace = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Set HYPRLAND_TRACE=1 and AQ_TRACE=1 environment variables for very
          verbose tracing. Writes massive logs to
          $XDG_RUNTIME_DIR/hypr/<instance>/hyprland.log. Disable after debugging
          to avoid performance impact.
        '';
      };
    };

    accelProfile = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "adaptive" "flat" ]);
      default = null;
      description = ''
        Mouse acceleration profile in the Hyprland input section.
        Set to "flat" when using maccel kernel module so libinput doesn't
        apply its own acceleration on top.
      '';
    };
  };
}
