{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.letta;
  backendBin =
    if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";
in
{
  config = lib.mkIf cfg.enable {
    systemd.services."${cfg.backend}-letta" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps = lib.mkOverride 90 cfg.restart.steps;

        ExecStartPre = lib.mkOverride 90
          "${pkgs.writeShellScript "letta-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";

        ExecStartPost = lib.mkOverride 90
          "${pkgs.writeShellScript "letta-container-probe" ''
            echo "[letta probe] waiting for API..."
            for i in $(${pkgs.coreutils}/bin/seq 1 60); do
              if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/v1/health > /dev/null 2>&1; then
                echo "[letta probe] API reachable (attempt $i)"
                exit 0
              fi
              sleep 1
            done
            echo "[letta probe] FAIL: API not reachable after 60s" >&2
            exit 1
          ''}";
      };
    };

    # Join ollama-net so letta can resolve ollama:11434 for model inference
    systemd.services."${cfg.backend}-letta-ollama-net" = lib.mkIf cfg.ollama.enable {
      description = "Connect letta container to ollama-net";
      after = [ "${cfg.backend}-letta.service" ];
      wants = [ "${cfg.backend}-letta.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "letta-join-ollama-net" ''
          ${backendBin} network connect ollama-net letta 2>/dev/null || true
        ''}";
      };
    };
  };
}
