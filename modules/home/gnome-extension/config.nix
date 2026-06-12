{ config, lib, pkgs, ... }:
let
  inherit (lib) types;
  cfg = config.my.gnomeExtensions.custom;
  extensions = lib.filterAttrs (name: ext: ext.enable) cfg.extensions;

  mkMetadata = ext: {
    name = ext.name;
    description = ext.description;
    uuid = ext.uuid;
    version = ext.version;
    "shell-version" = ext.shellVersions;
  } // lib.optionalAttrs (ext.url != "") {
    url = ext.url;
  };

  mkFiles = name: ext:
    let
      dir = ".local/share/gnome-shell/extensions/${ext.uuid}";

      baseFiles = [
        { name = "${dir}/metadata.json"; value = { text = builtins.toJSON (mkMetadata ext); }; }
        { name = "${dir}/extension.js";  value = { text = ext.extensionJs; }; }
      ];

      maybeStylesheet = lib.optional (ext.stylesheetCss != "") {
        name = "${dir}/stylesheet.css";
        value = { text = ext.stylesheetCss; };
      };

      extraFileList = lib.mapAttrsToList (filename: value: {
        name = "${dir}/${filename}";
        value = if builtins.isPath value
                then { source = value; }
                else { text = value; };
      }) ext.extraFiles;
    in
    baseFiles ++ maybeStylesheet ++ extraFileList;

  fileEntries = lib.listToAttrs (lib.flatten (lib.mapAttrsToList mkFiles extensions));
in
{
  config = lib.mkIf (extensions != { }) {
    home.file = fileEntries;
  };
}
