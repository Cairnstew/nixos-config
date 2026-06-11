{ config, lib, ... }:
let
  cfg = config.my.programs.tor-browser;
  torCfg = config.my.services.tor;
in
{
  assertions = [
    {
      assertion = !torCfg.client.enable || (torCfg.client.socksPort > 0 && torCfg.client.socksPort < 65536);
      message = "my.services.tor.client.socksPort must be a valid port (1-65535).";
    }

    {
      assertion = cfg.installMethod != "home" || config.my.homeManager.enable or false;
      message = "my.programs.tor-browser.installMethod = \"home\" but home-manager is not enabled.";
    }

    {
      assertion = !(cfg.enable && cfg.wrapper.useIPCTorService) || torCfg.enable;
      message = ''
        my.programs.tor-browser.wrapper.useIPCTorService is enabled but my.services.tor is not.
        The system Tor daemon must be running for IPC socket mode to work.
      '';
    }
  ];
}
