{ lib, config, pkgs, ... }:

let
  cfg = config.my.system.audio;
in
{
  options.my.system.audio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable PipeWire audio stack with Bluetooth and WirePlumber";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      audio.enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };

      pulse.enable = true;

      wireplumber.extraConfig = {
        "10-bluez" = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
          };
        };

        "11-bluetooth-policy" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };
    };

    # Disable legacy PulseAudio
    services.pulseaudio.enable = false;

    environment.systemPackages = with pkgs; [
      pavucontrol
      blueman
      pipewire
      wireplumber
    ];
  };
}
