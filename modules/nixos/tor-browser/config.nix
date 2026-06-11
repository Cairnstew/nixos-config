{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.tor-browser;
  torCfg = config.my.services.tor;
  inherit (flake.config.me) username;

  torBrowserPkg = lib.mkDefault (
    if cfg.package != null then
      cfg.package
    else
      pkgs.tor-browser.override {
        useIPCTorService = cfg.wrapper.useIPCTorService;
        disableContentSandbox = cfg.wrapper.disableContentSandbox;
        extraPrefs = cfg.wrapper.extraPrefs;
        audioSupport = cfg.wrapper.audioSupport;
        waylandSupport = cfg.wrapper.waylandSupport;
      }
  );

  useHomeManager = config.my.homeManager.enable or false;

  installViaHome = cfg.installMethod == "home" || (cfg.installMethod == "auto" && useHomeManager);
in
{
  config = lib.mkMerge [
    # ── Tor Browser installation ──────────────────────────────────────────────
    (lib.mkIf cfg.enable {
      home-manager.users.${username} = lib.mkIf installViaHome {
        home.packages = [ torBrowserPkg ];
      };

      environment.systemPackages = lib.mkIf (!installViaHome) [ torBrowserPkg ];
    })

    # ── System Tor daemon ─────────────────────────────────────────────────────
    (lib.mkIf torCfg.enable {
      services.tor = {
        enable = true;

        client.enable = lib.mkDefault torCfg.client.enable;
        client.socksListenAddress = lib.mkDefault (
          if torCfg.client.enable then torCfg.client.socksPort else null
        );

        relay.enable = lib.mkDefault torCfg.relay.enable;
        relay.role = lib.mkDefault torCfg.relay.role;

        openFirewall = lib.mkDefault torCfg.openFirewall;

        settings = lib.mkDefault torCfg.settings;

        controlSocket.enable = lib.mkDefault (
          cfg.enable && cfg.wrapper.useIPCTorService
        );
      };
    })

    # ── Assertions ────────────────────────────────────────────────────────────
    {
      assertions = [
        {
          assertion = cfg.installMethod != "home" || useHomeManager;
          message = ''
            my.programs.tor-browser.installMethod = "home" but home-manager is not enabled.
            Either set installMethod to "system" or enable my.homeManager.
          '';
        }
      ];
    }
  ];
}
