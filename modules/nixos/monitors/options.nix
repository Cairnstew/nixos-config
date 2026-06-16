{ lib, ... }:
{
  options.my.monitors = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "Connector name (e.g. DP-1, eDP-1, HDMI-A-1)";
        };
        width = lib.mkOption {
          type = lib.types.int;
          description = "Horizontal resolution in pixels";
        };
        height = lib.mkOption {
          type = lib.types.int;
          description = "Vertical resolution in pixels";
        };
        refreshRate = lib.mkOption {
          type = lib.types.number;
          default = 60;
          description = "Refresh rate in Hz";
        };
        scale = lib.mkOption {
          type = lib.types.number;
          default = 1;
          description = "Scale factor (1 = 100%, 1.5 = 150%)";
        };
        x = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "X position in the layout";
        };
        y = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Y position in the layout";
        };
        primary = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is the primary monitor";
        };
        workspace = lib.mkOption {
          type = lib.types.str;
          default = "1";
          description = "Workspace assigned to this monitor";
        };
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this monitor is enabled";
        };
        transform = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Display transform: 0=normal, 1=90°, 2=180°, 3=270°, 4-7=flipped variants";
        };
      };
    });
    default = [ ];
    description = "Declarative monitor layout, consumed by desktop environment modules";
    example = [
      {
        name = "DP-1";
        width = 2560;
        height = 1440;
        refreshRate = 144;
        x = 0;
        y = 0;
        primary = true;
        workspace = "1";
      }
      {
        name = "HDMI-A-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 2560;
        y = 0;
        workspace = "2";
      }
    ];
  };
}
