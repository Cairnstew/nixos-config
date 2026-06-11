{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types literalExpression;
in
{
  options = {
    my.programs.tor-browser = {
      enable = mkEnableOption "Tor Browser privacy-focused browser";

      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Tor Browser package to use. Defaults to pkgs.tor-browser.";
        example = literalExpression "pkgs.tor-browser.override { waylandSupport = false; }";
      };

      installMethod = mkOption {
        type = types.enum [ "auto" "home" "system" ];
        default = "auto";
        description = ''
          Where to install Tor Browser.
          - "auto": use home-manager if enabled, fall back to system packages.
          - "home": install via home-manager home.packages (asserts HM is enabled).
          - "system": install via environment.systemPackages.
        '';
      };

      wrapper = {
        useIPCTorService = mkOption {
          type = types.bool;
          default = false;
          description = "Use system Tor daemon via IPC sockets instead of the bundled Tor.";
        };

        disableContentSandbox = mkOption {
          type = types.bool;
          default = false;
          description = "Disable Firefox multi-process content sandbox.";
        };

        extraPrefs = mkOption {
          type = types.lines;
          default = "";
          description = "Extra Firefox preferences injected into mozilla.cfg.";
          example = ''
            lockPref("extensions.torbutton.use_nontor_proxy", true);
            lockPref("privacy.firstparty.isolate", true);
          '';
        };

        audioSupport = mkOption {
          type = types.bool;
          default = true;
          description = "Enable audio playback support.";
        };

        waylandSupport = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Wayland support (MOZ_ENABLE_WAYLAND=1).";
        };
      };
    };

    my.services.tor = {
      enable = mkEnableOption "system Tor daemon";

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for Tor relay.";
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Raw torrc settings passed through to services.tor.settings.";
        example = {
          SOCKSPort = "9050";
          ControlPort = "9051";
          CookieAuthentication = "1";
        };
      };

      client = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Route application connections through Tor (SOCKS proxy).";
        };

        socksPort = mkOption {
          type = types.port;
          default = 9050;
          description = "SOCKS proxy listen port.";
        };
      };

      relay = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Run a Tor relay to help the network.";
        };

        role = mkOption {
          type = types.enum [ "relay" "bridge" "exit" "private-bridge" ];
          default = "relay";
          description = "Type of Tor relay to run.";
        };
      };
    };
  };
}
