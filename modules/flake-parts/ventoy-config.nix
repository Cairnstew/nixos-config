{ config, lib, inputs, ... }:
let
  inherit (lib) mapAttrsToList;

  # Collect every host's ISOs into one flat attrset, NOT via mkMerge.
  # mkMerge would leak _type / list keys into the attrset, confusing
  # the attrsOf submodule type check.
  hostIsos = builtins.foldl' (acc: hostName:
    let
      hostCfg = config.flake.nixosConfigurations.${hostName} or { };
      ventoyCfg = hostCfg.config.my.ventoy or { };
    in
    if ventoyCfg.enable or false then
      acc // ventoyCfg.isos or { }
    else
      acc
  ) { } (builtins.attrNames (config.flake.nixosConfigurations or { }));
in
{
  ventoy = {
    settings = {
      control = [
        { VTOY_DEFAULT_MENU_MODE = "0"; }
        { VTOY_TREE_VIEW_MENU_STYLE = "0"; }
        { VTOY_DEFAULT_SEARCH_ROOT = "/iso"; }
        { VTOY_FILT_DOT_UNDERSCORE_FILE = "1"; }
        { VTOY_WIN11_BYPASS_CHECK = "1"; }
        { VTOY_WIN11_BYPASS_NRO = "1"; }
      ];
      menu_class = [
        { parent = "/iso/windows"; class = "windows"; }
        { parent = "/iso/linux";   class = "linux"; }
      ];
      menu_alias = [
        { image = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso"; alias = "Windows 11 23H2 Pro"; }
        { dir   = "/iso/linux";   alias = "[ Linux ISOs ]"; }
      ];
    };

    installOptions = { };

    buildInstallerIso = true;

    answerFileSettings = {
      username = config.me.username;
      hostname = config.me.username + "-win";
      diskId = "0";
    };

    isos = hostIsos;

    settings.auto_install = [
      {
        image = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
        template = [
          "/ventoy/scripts/dev.xml"
          "/ventoy/scripts/minimal.xml"
          "/ventoy/scripts/domain.xml"
          "/ventoy/scripts/kiosk.xml"
          "/ventoy/scripts/dual-boot.xml"
        ];
      }
    ];

  };
}
