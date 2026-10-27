{ config, lib, ... }:

let
  cfg = config.my.programs.obs-studio;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(lib.elem cfg.package cfg.plugins);
        message = "my.programs.obs-studio.plugins must not contain the OBS package itself.";
      }
      {
        assertion = cfg.recordingPath == null || lib.hasPrefix "/" cfg.recordingPath;
        message = "my.programs.obs-studio.recordingPath must be an absolute path.";
      }
    ];
  };
}
