# modules/nixos/profiles/system/gaming.nix
# Gaming profile with Steam, gaming tools, and mouse acceleration
{ config, lib, flake, ... }:
let
  cfg = config.my.profiles.gaming;
  inherit (flake.config.me) username;
in
{
  config = lib.mkIf cfg.enable {
    # ── Gaming dependencies ────────────────────────────────────────────────
    my.system.audio.enable = lib.mkDefault true;
    my.programs.steam.enable = lib.mkDefault true;

    # ── Mouse Acceleration (logistic-like S-curve) ─────────────────────────
    # X11 / XWayland layer — applies to games running under XWayland
    # The curve approximates a logistic function: smooth takeoff from low
    # speeds (precise aiming), gradual ramp in mid-range, plateau at top.
    #   Speed:   0.0  0.1  0.2  0.3  0.4  0.5  0.6  0.7  0.8  0.9  1.0
    #   Factor:  0.0  0.01 0.03 0.08 0.18 0.35 0.55 0.75 0.88 0.95 1.0
    services.libinput.mouse = {
      accelProfile = "custom";
      accelPointsMotion = [ 0.0 0.01 0.03 0.08 0.18 0.35 0.55 0.75 0.88 0.95 1.0 ];
      accelStepMotion = 0.1;
      accelPointsFallback = [ 0.0 0.01 0.03 0.08 0.18 0.35 0.55 0.75 0.88 0.95 1.0 ];
      accelStepFallback = 0.1;
    };

    # GNOME Wayland layer — mutter reads dconf, not xorg.conf.d.
    # GNOME only supports "default" (adaptive) or "flat"; set speed to
    # match the user's preferred GNOME slider position.
    home-manager.users.${username}.dconf.settings."org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "default";
      speed = 1.0;
    };
  };
}
