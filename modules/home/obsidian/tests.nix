{ config, lib, ... }:

let
  cfg = config.my.programs.obsidian;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.defaultDirectory != "";
        message = "my.programs.obsidian.defaultDirectory must not be empty.";
      }
      {
        assertion = !cfg.repo.enable || cfg.repo.url != "";
        message = "my.programs.obsidian.repo.url must be set when repo.enable is true.";
      }
    ];
  };
}
