{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.system.audio;
  vm = cfg.virtualMixer;
  username = flake.config.me.username;

  channelNames = [ "FL" "FR" "FC" "LFE" "RL" "RR" ];

  mkVirtualSink = s: {
    factory = "adapter";
    args = {
      "factory.name" = "support.null-audio-sink";
      "node.name" = s.name;
      "node.description" = s.description;
      "media.class" = "Audio/Sink";
      "audio.position" = lib.take s.channels channelNames;
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    services = {
      pipewire = {
        enable = true;
        audio.enable = true;
        alsa = { enable = true; support32Bit = true; };
        pulse.enable = true;

        wireplumber.extraConfig =
          {
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
          }
          // lib.optionalAttrs (cfg.mic.enable && cfg.mic.name != null) {
            # Declared default microphone — baked into WirePlumber config at build
            # time so the chosen mic is the system default source (no runtime step).
            "10-default-source" = {
              "wireplumber.settings" = {
                "default.audio.source" = cfg.mic.name;
              };
            };
          };

        # Declarative virtual sinks (Pulsemeeter manages its own buses at runtime).
        extraConfig.pipewire = lib.mkIf (vm.enable && vm.virtualSinks != [ ]) {
          "10-virtual-sinks" = {
            "context.objects" = map mkVirtualSink vm.virtualSinks;
          };
        };
      };
      pulseaudio.enable = false;
    };
    security.rtkit.enable = true;
    environment.systemPackages = with pkgs; [
      pavucontrol
      blueman
      pipewire
      wireplumber
    ] ++ lib.optionals vm.enable ([
      pulsemeeter
    ]
    ++ lib.optional vm.effects easyeffects
    ++ lib.optional (vm.patchbay == "qpwgraph") qpwgraph);

    home-manager.users.${username}.systemd.user.services = lib.mkIf (vm.enable && vm.autostart) {
      pulsemeeter = {
        Unit = {
          Description = "Pulsemeeter virtual audio mixer";
          After = [ "pipewire-pulse.service" ];
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.pulsemeeter}/bin/pulsemeeter";
          Restart = "on-failure";
        };
      };
      easyeffects = lib.mkIf vm.effects {
        Unit = {
          Description = "EasyEffects audio effects service";
          After = [ "pipewire.service" "pipewire-pulse.service" ];
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
          Restart = "on-failure";
        };
      };
    };
  };
}
