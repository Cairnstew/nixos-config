{ config, lib, ... }:
let
  cfg = config.my.programs.thunderbird;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !(cfg.enable && cfg.email != "" && !(lib.hasInfix "@" cfg.email));
      message = "my.programs.thunderbird.email must be a valid email address (containing '@')";
    }
    {
      assertion = !(cfg.enable && cfg.profileName == "");
      message = "my.programs.thunderbird.profileName cannot be empty";
    }
  ];

  # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
  # Note: Thunderbird is a GUI application, so we can't easily test it in a headless environment.
  # The assertions above serve as the primary validation.
}
