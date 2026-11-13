# modules/home/superfile/packages.nix
# superfile resolves its previewers and plugins on PATH (`exec.Command`), it
# does not link them. Deriving the packages from the merged settings keeps the
# config and the environment from drifting apart — setting
# `settings.metadata = true` without exiftool would otherwise fail at runtime
# with only a log line.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.superfile;
  settings = import ./merge.nix { inherit lib cfg; };
  on = key: settings.${key} or false;
in
{
  config = lib.mkIf cfg.enable {
    home.packages =
      [ cfg.package ]
      ++ lib.optional ((settings.code_previewer or "") == "bat") pkgs.bat
      ++ lib.optional ((settings.show_image_preview or false) && cfg.previews.pdf) pkgs.poppler-utils
      ++ lib.optional cfg.previews.video pkgs.ffmpeg
      ++ lib.optional (on "metadata") pkgs.exiftool
      ++ lib.optional (on "zoxide_support") pkgs.zoxide
      ++ cfg.extraPackages;
  };
}
