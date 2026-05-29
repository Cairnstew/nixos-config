{ config, lib, inputs, ... }:
let
  inherit (lib) mkMerge mapAttrsToList;

  hostIsos = mkMerge (mapAttrsToList (hostName: hostCfg:
    let ventoyCfg = hostCfg.config.my.ventoy or { }; in
    if ventoyCfg.enable or false then
      ventoyCfg.isos or { }
    else
      { }
  ) (config.flake.nixosConfigurations or {}));

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

    answerFileSettings = {
      username = config.me.username;
      hostname = config.me.username + "-win";
      diskId = "0";
    };

    isos = {
      gparted = {
        source = "${inputs.gparted-iso}";
        target = "/iso/linux/gparted-live-1.6.0-1-amd64.iso";
      };
    } // hostIsos;

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
