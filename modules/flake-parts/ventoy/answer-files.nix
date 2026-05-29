{ config, lib, ... }:
let
  vCfg = config.ventoy;

in
{
  config.perSystem = { pkgs, ... }:
    let
      answerSettings = vCfg.answerFileSettings;

      answerTemplates = {
        dev = ../../../packages/ventoy/answer-files/dev.xml;
        minimal = ../../../packages/ventoy/answer-files/minimal.xml;
        domain = ../../../packages/ventoy/answer-files/domain.xml;
        kiosk = ../../../packages/ventoy/answer-files/kiosk.xml;
        dual-boot = ../../../packages/ventoy/answer-files/dual-boot.xml;
      };

      wipeDiskPart = ../../../packages/ventoy/answer-files/partials/wipe-disk.xml;

      replaceInXml = template: replacements:
        let
          templateText = builtins.readFile template;
          from = builtins.attrNames replacements;
          to = builtins.attrValues replacements;
        in
        builtins.replaceStrings from to templateText;

      buildAnswer =
        { name
        , productKey
        , computerName
        , username
        , password
        , autoLogonCount ? "1"
        , lang ? "en-GB"
        , timezone ? "GMT Standard Time"
        , arch ? "amd64"
        , networkLocale ? "Work"
        , protectYourPC ? "3"
        , wipeDisk ? false
        }:
        let
          archId = if arch == "amd64" then "x86_64" else arch;
          attest = {
            "@productKey@" = productKey;
            "@computerName@" = computerName;
            "@username@" = username;
            "@password@" = password;
            "@autoLogonCount@" = autoLogonCount;
            "@lang@" = lang;
            "@timezone@" = timezone;
            "@arch@" = arch;
            "@archId@" = archId;
            "@networkLocale@" = networkLocale;
            "@protectYourPC@" = protectYourPC;
            "@diskId@" = answerSettings.diskId;
            "@wipeDiskBlock@" = if wipeDisk then builtins.readFile wipeDiskPart else "";
          };
        in
        pkgs.writeText "${name}.xml" (replaceInXml answerTemplates.${name} attest);

      answerFileConfigs = {
        dev = {
          name = "dev";
          computerName = "DEV-PC-####";
          username = "seanc";
          password = "password";
          autoLogonCount = "3";
        };
        minimal = {
          name = "minimal";
          computerName = "MIN-####";
          username = "user";
          password = "password";
        };
        domain = {
          name = "domain";
          computerName = "CORP-####";
          username = "user";
          password = "password";
        };
        kiosk = {
          name = "kiosk";
          computerName = "KIOSK-####";
          username = "kiosk";
          password = "kiosk";
          autoLogonCount = "999";
        };
        dual-boot = {
          name = "dual-boot";
          computerName = answerSettings.hostname;
          username = answerSettings.username;
          password = answerSettings.password;
          autoLogonCount = "1";
          wipeDisk = true;
        };
      };

      answerFilePackages = lib.mapAttrs'
        (n: v:
          lib.nameValuePair "windows-answ-pro-${n}" (buildAnswer {
            inherit (v) name computerName username password;
            productKey = "VK7JG-NPHTM-C97JM-9MPGT-3V66T";
            autoLogonCount = v.autoLogonCount or "1";
            wipeDisk = v.wipeDisk or false;
            lang = "en-GB";
            timezone = "GMT Standard Time";
            arch = "amd64";
          })
        )
        answerFileConfigs;

    in
    {
      packages = answerFilePackages;
    };
}
