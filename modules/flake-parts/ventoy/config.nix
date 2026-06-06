{ config, lib, ... }:
let
  hostIsos = builtins.foldl'
    (acc: hostName:
      let
        hostCfg = config.flake.nixosConfigurations.${hostName} or { };
        ventoyCfg = hostCfg.config.my.ventoy or { };
        isos = ventoyCfg.isos or { };
      in
      if ventoyCfg.enable or false then
        acc // isos
      else
        acc
    )
    { }
    (builtins.attrNames (config.flake.nixosConfigurations or { }));
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
        { parent = "/iso/linux"; class = "linux"; }
      ];
      menu_alias = [
        { image = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso"; alias = "Windows 11 23H2 Pro"; }
        { dir = "/iso/linux"; alias = "[ Linux ISOs ]"; }
      ];
      menu_tip = {
        tips = [
          {
            image = "/iso/linux/deploy.iso";
            tip = "Auto-connects to Tailscale (tag:temp, encrypted auth). SSH: root@<hostname>";
          }
        ];
      };
    };

    installOptions = { };

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
