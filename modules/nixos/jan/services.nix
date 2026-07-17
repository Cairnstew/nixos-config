{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.jan;
  username = flake.config.me.username;
in
{
  config = lib.mkIf (cfg.enable && cfg.apiServer.enable) {
    home-manager.users.${username}.systemd.user.services.jan.Service = {
      ExecStartPost = "${pkgs.writeShellScript "jan-container-probe" ''
        echo "[jan probe] waiting for API server..."
        for i in $(${pkgs.coreutils}/bin/seq 1 15); do
          if ${pkgs.curl}/bin/curl -sf http://${cfg.apiServer.host}:${toString cfg.apiServer.port}/v1/models > /dev/null 2>&1; then
            echo "[jan probe] API reachable (attempt $i)"
            exit 0
          fi
          sleep 1
        done
        echo "[jan probe] FAIL: API not reachable after 15s" >&2
        exit 1
      ''}";
    };
  };
}
