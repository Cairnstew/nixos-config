{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.bootHealth;

  healthPkg = pkgs.writeShellApplication {
    name = "boot-health";
    runtimeInputs = with pkgs; [ coreutils systemd nix ];
    text = ''
      ROLLBACK_FLAG="${cfg.stateDir}/rollback-attempted"
      EMERGENCY_FLAG="/var/lib/boot-alerting/emergency-flag"
      LAST_BOOT_OK="${cfg.stateDir}/last-boot-ok"

      # Step 1: Always clear any previous rollback marker (fresh boot)
      rm -f "$ROLLBACK_FLAG"

      # Step 2: Check if emergency flag was left behind (belt-and-suspenders)
      if [[ -f "$EMERGENCY_FLAG" ]]; then
        echo "boot-health: emergency flag still present -- boot-failure-detector may not have run" | \
          ${pkgs.systemd}/bin/systemd-cat -t boot-health -p warning
      fi

    '' + lib.optionalString cfg.autoRollback.enable ''
      # Step 3: Auto-rollback logic (only if enabled)
      if [[ -f "$ROLLBACK_FLAG" ]]; then
        echo "ROLLBACK SKIPPED: rollback already attempted this boot cycle" | \
          ${pkgs.systemd}/bin/systemd-cat -t boot-health -p crit
      elif [[ ! -f "$LAST_BOOT_OK" ]]; then
        echo "ROLLBACK SKIPPED: first boot (no previous last-boot-ok marker), skipping rollback" | \
          ${pkgs.systemd}/bin/systemd-cat -t boot-health -p warning
      elif [[ -f "$EMERGENCY_FLAG" ]]; then
        echo "ROLLBACK: emergency.target was reached in previous boot, rolling back now" | \
          ${pkgs.systemd}/bin/systemd-cat -t boot-health -p crit
        touch "$ROLLBACK_FLAG"
        ${pkgs.nix}/bin/nix-env --rollback -p /nix/var/nix/profiles/system \
          >> /tmp/boot-health-rollback.log 2>&1
        ${pkgs.systemd}/bin/systemctl reboot
      fi
    '' + ''
      # Step 4: Write success marker only if no emergency flag present
      if [[ ! -f "$EMERGENCY_FLAG" ]]; then
        ${pkgs.coreutils}/bin/date -u > "$LAST_BOOT_OK"
        echo "boot-health: clean boot recorded" | \
          ${pkgs.systemd}/bin/systemd-cat -t boot-health -p info
      else
        echo "boot-health: emergency flag present -- skipping last-boot-ok" | \
          ${pkgs.systemd}/bin/systemd-cat -t boot-health -p warning
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.boot-health = {
      description = "Record clean boot and optionally trigger rollback on failure";
      after = [ "multi-user.target" "boot-failure-detector.service" ];
      wants = [ "boot-failure-detector.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "boot-health";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 300";
        ExecStart = "${healthPkg}/bin/boot-health";
      };
    };
  };
}
