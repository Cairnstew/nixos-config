{
  name = "audio";
  description = "PipeWire audio stack with ALSA, PulseAudio compat, Bluetooth codecs, WirePlumber, a declared default mic, and a Pulsemeeter + EasyEffects virtual mixer";
  category = "system";
  tags = [ "audio" "pipewire" "sound" "bluetooth" "wireplumber" "virtual-mixer" "pulsemeeter" "easyeffects" ];
  provides = [ "my.system.audio" "my.system.audio.virtualMixer" "my.system.audio.mic" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
