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
      description = "Generate Neko container env + neko.yaml from agenix secrets";
      before = [ "${cfg.backend}-neko.service" ];
      requiredBy = [ "${cfg.backend}-neko.service" ];
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
        # v3 neko reads member passwords from /etc/neko/neko.yaml (the baked
        # config hardcodes admin/admin + user/neko and IGNORES the legacy
        # NEKO_MEMBER_MULTIUSER_* env vars — login rejects anything else).
        # Regenerate the yaml from the module options + secrets, then mount it
        # (see volumes in config.nix) so the real agenix passwords work.
        # YAML indentation is written LITERALLY via printf (Nix indented-string
        # stripping otherwise eats the sub-key indent); the file is left for
        # /run/neko/env untouched for any legacy env consumers.
        rm -f /run/neko/neko.yaml
        ${pkgs.coreutils}/bin/printf 'desktop:\n  screen: "%s"\n' '${cfg.desktopScreen}' > /run/neko/neko.yaml
        ${pkgs.coreutils}/bin/printf 'member:\n  provider: "multiuser"\n  multiuser:\n' >> /run/neko/neko.yaml
        ${lib.optionalString (cfg.adminPasswordFile != null) ''
        ${pkgs.coreutils}/bin/printf '    admin_password: "%s"\n' "$(cat ${lib.escapeShellArg cfg.adminPasswordFile})" >> /run/neko/neko.yaml
        ''}
        ${lib.optionalString (cfg.userPasswordFile != null) ''
        ${pkgs.coreutils}/bin/printf '    user_password: "%s"\n' "$(cat ${lib.escapeShellArg cfg.userPasswordFile})" >> /run/neko/neko.yaml
        ''}
        ${pkgs.coreutils}/bin/printf 'session:\n  merciful_reconnect: true\n  # Single-user-friendly default: the first member who connects can control\n  # immediately (input + hosting) instead of needing to click "host".\n  implicit_hosting: true\n  cookie:\n    enabled: false\n' >> /run/neko/neko.yaml
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
