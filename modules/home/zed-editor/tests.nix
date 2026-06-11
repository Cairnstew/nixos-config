{ config, lib, ... }:

let
  cfg = config.my.programs.zed-editor;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.fontSize > 0;
        message = "my.programs.zed-editor.fontSize must be positive.";
      }
      {
        assertion = cfg.tabSize > 0;
        message = "my.programs.zed-editor.tabSize must be positive.";
      }
      {
        assertion = cfg.preferredLineLength > 0;
        message = "my.programs.zed-editor.preferredLineLength must be positive.";
      }
      {
        assertion = cfg.autosaveDelay > 0;
        message = "my.programs.zed-editor.autosaveDelay must be positive.";
      }
      {
        assertion = cfg.git.inlineBlameDelay > 0;
        message = "my.programs.zed-editor.git.inlineBlameDelay must be positive.";
      }
      {
        assertion = cfg.fontFamily != "";
        message = "my.programs.zed-editor.fontFamily must not be empty.";
      }
    ];
  };
}
