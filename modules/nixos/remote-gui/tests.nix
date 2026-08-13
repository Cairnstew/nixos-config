{ config, lib, ... }:

let
  cfg = config.my.services.remoteGui;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    assertions = [
      {
        assertion = lib.hasPrefix ":" cfg.display;
        message = "my.services.remoteGui.display must start with ':' (e.g. ':10').";
      }
      {
        assertion = lib.all (app: app.command != "") (lib.attrValues cfg.apps);
        message = "Every my.services.remoteGui.apps.<name>.command must be non-empty.";
      }
      {
        assertion = lib.all (app: config.users.users ? ${app.user}) (lib.attrValues cfg.apps);
        message = "my.services.remoteGui.apps.<name>.user must be an existing system user.";
      }
    ];

    # ── L2: Smoke-test oneshot ────────────────────────────────────────────────
    systemd.services.remote-gui-smoke-test = {
      description = "remote-gui smoke test: verify display, VNC, and app units";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        set -u
        if ! systemctl is-active --quiet remote-gui-xvfb.service; then
          echo "[smoke] FAIL: remote-gui-xvfb.service not active" >&2
          exit 1
        fi
        ${lib.optionalString cfg.vnc.enable ''
          if ! ss -ltn | grep -q ":${toString cfg.vnc.port} "; then
            echo "[smoke] FAIL: x11vnc not listening on :${toString cfg.vnc.port}" >&2
            exit 1
          fi
        ''}
        ${lib.concatStrings (lib.mapAttrsToList (name: _: ''
          if ! systemctl show -p Id --value remote-gui-app-${name}.service > /dev/null 2>&1; then
            echo "[smoke] FAIL: remote-gui-app-${name}.service missing" >&2
            exit 1
          fi
        '') cfg.apps)}
        echo "[smoke] ALL REMOTE-GUI CHECKS PASSED"
      '';
    };
  };
}
