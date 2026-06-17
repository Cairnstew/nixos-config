{ lib, ... }:
{
  options.my.desktop.hyprland.core = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Hyprland compositor core (programs.hyprland, env vars, hyprland.conf).";
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

    windowOpacity = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable default window opacity overlay. Sets decoration:active_opacity and decoration:inactive_opacity for global window transparency.";
      };

      focused = lib.mkOption {
        type = lib.types.float;
        default = 0.97;
        example = 0.95;
        description = "Opacity for focused/active windows, rendered as decoration:active_opacity (0.0 = fully transparent, 1.0 = fully opaque).";
      };

      unfocused = lib.mkOption {
        type = lib.types.float;
        default = 0.92;
        example = 0.85;
        description = "Opacity for unfocused/inactive windows, rendered as decoration:inactive_opacity (0.0 = fully transparent, 1.0 = fully opaque).";
      };

      overrides = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            class = lib.mkOption {
              type = lib.types.str;
              example = "steam";
              description = "Window class to match. Use hyprctl clients to discover class names.";
            };
            focused = lib.mkOption {
              type = lib.types.float;
              default = 1.0;
              description = "Opacity when focused (0.0-1.0).";
            };
            unfocused = lib.mkOption {
              type = lib.types.float;
              default = 1.0;
              description = "Opacity when unfocused (0.0-1.0).";
            };
          };
        });
        default = [ ];
        example = [
          { class = "steam"; focused = 1.0; unfocused = 1.0; }
          { class = "mpv"; focused = 0.99; }
        ];
        description = "Per-class opacity overrides for specific applications (generates windowrule = opacity with class target). All values default to 1.0.";
      };
    };

    extraWindowRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "float, class:^(pavucontrol)$"
        "tile, class:^(firefox)$"
      ];
      description = ''
        Additional windowrule lines appended to the window rules section of
        hyprland.conf. Supports all Hyprland window rule directives (float,
        tile, size, move, center, opacity, etc). Each entry becomes a
        `windowrule = <entry>` line.
      '';
    };
  };
}
