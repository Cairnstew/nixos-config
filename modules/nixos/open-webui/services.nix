{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.open-webui;
  backendBin =
    if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";
in
{
  config = lib.mkIf cfg.enable {
    systemd.services."${cfg.backend}-open-webui" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps = lib.mkOverride 90 cfg.restart.steps;

        ExecStartPre = lib.mkOverride 90
          "${pkgs.writeShellScript "open-webui-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";

        ExecStartPost = lib.mkOverride 90
          "${pkgs.writeShellScript "open-webui-container-probe" ''
            echo "[open-webui probe] waiting for web UI..."
            for i in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/ > /dev/null 2>&1; then
                echo "[open-webui probe] UI reachable (attempt $i)"
                exit 0
              fi
              sleep 1
            done
            echo "[open-webui probe] FAIL: UI not reachable after 30s" >&2
            exit 1
          ''}";
      };
    };
  };
}
