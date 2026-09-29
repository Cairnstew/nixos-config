{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mailFilter;
  testScript = pkgs.writeShellScript "mail-filter-smoke-test" ''
    set -euo pipefail
    SCRIPT="$HOME/.config/mail-filter/filter.sieve"
    CONF="$HOME/.config/mail-filter/dovecot.conf"
    [ -f "$SCRIPT" ] || { echo "smoke: filter.sieve missing — module not activated?"; exit 1; }
    [ -f "$CONF" ] || { echo "smoke: dovecot.conf missing"; exit 1; }

    # L2: compile the generated script. sievec exits non-zero on a Sieve error.
    sievec -c "$CONF" "$SCRIPT"
    echo "smoke: sievec compile OK (filter.svbin written)"

    # L2: run sieve-filter in simulation mode against INBOX — proves the
    # config parses (exit 78 would mean config error) and prints planned moves
    # without changing anything. Pass the SOURCE script path (0.5 resolves
    # filter.svbin by basename).
    sieve-filter -c "$CONF" -v -m INBOX "$SCRIPT" INBOX keep >/tmp/mail-filter-smoke.out 2>&1 || {
      echo "smoke: sieve-filter failed with $?"
      cat /tmp/mail-filter-smoke.out
      exit 1
    }
    echo "smoke: sieve-filter simulation OK"
  '';
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.address != "";
        message = "my.services.mailFilter.address must be set (flake.config.me.email is empty).";
      }
      {
        assertion = cfg.secretName != "";
        message = "my.services.mailFilter.secretName must not be empty.";
      }
      {
        assertion = (lib.filter (t: t.matchers or [ ] != [ ] && (t.path or "") == "") (lib.attrValues cfg.tags)) == [ ];
        message = "my.services.mailFilter.tags: every tag with matchers needs a non-empty 'path'.";
      }
      {
        assertion = cfg.filter.sourceMailbox != "";
        message = "my.services.mailFilter.filter.sourceMailbox must not be empty.";
      }
    ];

    # L2 smoke test — triggered manually: systemctl --user start mail-filter-smoke-test
    systemd.user.services.mail-filter-smoke-test = {
      Unit = {
        Description = "Smoke test for the Sieve mail filter (compile + dry-run filter)";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${testScript}";
      };
    };
  };
}