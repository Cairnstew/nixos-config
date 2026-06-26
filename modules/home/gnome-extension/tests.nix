{ config, lib, ... }:
let
  cfg = config.my.gnomeExtensions.custom;
  enabled = lib.filterAttrs (name: ext: ext.enable) cfg.extensions;
in
{
  config = lib.mkIf (enabled != { }) {
    assertions = lib.flatten (lib.mapAttrsToList
      (name: ext: [
        {
          assertion = ext.extensionJs != "";
          message = "my.gnomeExtensions.custom.extensions.${name}.extensionJs must not be empty when enabled.";
        }
        {
          assertion = builtins.match "^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+$" ext.uuid != null;
          message = "my.gnomeExtensions.custom.extensions.${name}.uuid must be a valid GNOME Shell extension UUID (e.g. 'my-ext@domain'). Got: ${ext.uuid}";
        }
      ])
      enabled);
  };
}
