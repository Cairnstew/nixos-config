{flake, lib, config, pkgs, ... }:
let
  inherit (flake) config inputs;
  inherit (flake.inputs) self;
in
{

  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
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
    
  services.pulseaudio.enable = false;
  
  environment.systemPackages = with pkgs; [
    pavucontrol
    blueman
    pipewire
    #pipewire-pulse
    #pipewire-alsa
    wireplumber
    #pipewire-bt
  ];
  
}
