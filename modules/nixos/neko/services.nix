{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.neko;
  backendBin =
    if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.neko-envfile = lib.mkIf (cfg.adminPasswordFile != null || cfg.userPasswordFile != null) {
      description = "Generate Neko container env file from agenix secrets";
      before = [ "docker-neko.service" ];
      requiredBy = [ "docker-neko.service" ];
      script = ''
        mkdir -p /run/neko
        cat > /run/neko/env << EOF
        ${lib.optionalString (cfg.adminPasswordFile != null) ''
        NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD=$(cat ${lib.escapeShellArg cfg.adminPasswordFile})
        ''}
        ${lib.optionalString (cfg.userPasswordFile != null) ''
        NEKO_MEMBER_MULTIUSER_USER_PASSWORD=$(cat ${lib.escapeShellArg cfg.userPasswordFile})
        ''}
        EOF
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services."${cfg.backend}-neko" = {
      serviceConfig = {
        ExecStartPre = lib.mkOverride 90
          "${pkgs.writeShellScript "neko-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";
      };
    };
  };
}
