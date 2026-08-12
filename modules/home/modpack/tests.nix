{ config, lib, ... }:

let
  cfg = config.my.programs.modpack;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "http://" cfg.modrinth.baseUrl
          || lib.hasPrefix "https://" cfg.modrinth.baseUrl;
        message = "my.programs.modpack.modrinth.baseUrl must be an http(s) URL";
      }
      {
        assertion = cfg.modrinth.userAgent != "";
        message = "my.programs.modpack.modrinth.userAgent must not be empty (Modrinth requires a descriptive User-Agent)";
      }
    ];
  };
}
