{ lib, ... }:
{
  options.my.hardware.mouse = {
    enable = lib.mkEnableOption "Mouse acceleration via maccel kernel module";

    parameters = {
      mode = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "linear" "natural" "synchronous" "no_accel" ]);
        default = "linear";
        description = "Acceleration curve mode.";
      };

      sensMultiplier = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = 2.0;
        description = "Sensitivity multiplier applied after acceleration calculation.";
      };

      yxRatio = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "Y/X ratio - factor by which Y-axis sensitivity is multiplied.";
      };

      inputDpi = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x > 0.0)
          // { description = "positive float"; });
        default = null;
        description = "DPI of the mouse, used to normalize effective DPI.";
      };

      angleRotation = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "Apply rotation in degrees to mouse movement input.";
      };

      acceleration = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = 0.3;
        description = "Linear acceleration factor.";
      };

      offset = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x >= 0.0)
          // { description = "non-negative float"; });
        default = 4.0;
        description = "Input speed past which to allow acceleration.";
      };

      outputCap = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = 2.0;
        description = "Maximum sensitivity multiplier cap.";
      };

      decayRate = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x > 0.0)
          // { description = "positive float"; });
        default = null;
        description = "Decay rate of the Natural acceleration curve.";
      };

      limit = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x >= 1.0)
          // { description = "float >= 1.0"; });
        default = null;
        description = "Limit of the Natural acceleration curve.";
      };

      gamma = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x > 0.0)
          // { description = "positive float"; });
        default = null;
        description = "Controls how fast you get from low to fast around the midpoint.";
      };

      smooth = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x >= 0.0 && x <= 1.0)
          // { description = "float between 0.0 and 1.0"; });
        default = null;
        description = "Controls the suddenness of the sensitivity increase.";
      };

      motivity = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x > 1.0)
          // { description = "float > 1.0"; });
        default = null;
        description = "Sets max sensitivity while setting min to 1/motivity.";
      };

      syncSpeed = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (x: x > 0.0)
          // { description = "positive float"; });
        default = null;
        description = "Sets the middle sensitivity between min and max sensitivity.";
      };
    };

    logging = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Periodically log maccel state to journald for diagnostics.
          Helps detect when maccel parameters change unexpectedly or the module stops working.
        '';
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "5min";
        example = "1min";
        description = "How often to check and log maccel state. Systemd timer interval format.";
      };

      watch = lib.mkEnableOption "maccel-watch CLI helper for interactive real-time monitoring" // { default = true; };

      logAll = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Log all parameters on every check. When false, only logs when
          current values differ from the configured expected values.
        '';
      };

      sysfsWatch = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Watch the maccel sysfs files for changes via systemd path units.
          Logs immediately when a parameter is modified outside of the expected configuration.
        '';
      };
    };

    gnome = {
      accelProfile = lib.mkOption {
        type = lib.types.str;
        default = "flat";
        description = "GNOME mouse acceleration profile ('flat' disables built-in accel).";
      };

      speed = lib.mkOption {
        type = lib.types.float;
        default = 0.0;
        description = "GNOME pointer speed (-1.0 slow, 0.0 neutral, 1.0 fast).";
      };
    };
  };
}
