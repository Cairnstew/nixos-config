{ lib, ... }:
{
  options.my.profiles = {
    # ── Role Profiles ──────────────────────────────────────────────────────
    workstation.enable = lib.mkEnableOption "workstation profile (desktop/laptop)";
    server.enable = lib.mkEnableOption "server profile (headless)";
    minimal.enable = lib.mkEnableOption "minimal profile (bare essentials)";
    gaming.enable = lib.mkEnableOption "gaming profile (steam, games, etc.)";
    media.enable = lib.mkEnableOption "media stack profile (Prowlarr, Sonarr, Radarr, Jellyfin)";
    entertainment.enable = lib.mkEnableOption "entertainment profile (gaming, music, media services)";
    development.enable = lib.mkEnableOption "development profile (dev tools, containers)";
    ai.enable = lib.mkEnableOption "AI frontend services (RisuAI, Open WebUI, Letta, Jan)";

    # ── Feature Profiles ─────────────────────────────────────────────────
    desktop.choice = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "hyprland" "gnome" ]);
      default = null;
      example = "hyprland";
      description = "Which desktop environment to use. Set to null (default) to pick none, or use desktop.hyprland.enable / desktop.gnome.enable directly.";
    };
    desktop.hyprland.enable = lib.mkEnableOption "Hyprland Wayland compositor";
    desktop.gnome.enable = lib.mkEnableOption "GNOME desktop environment";

    gpu.mesa.enable = lib.mkEnableOption "Mesa GPU drivers (Intel/AMD)";
    gpu.nvidia.enable = lib.mkEnableOption "NVIDIA GPU drivers";
    gpu.nvidia-headless.enable = lib.mkEnableOption "NVIDIA GPU drivers (headless/CUDA)";

    testing.enable = lib.mkEnableOption "testing profile (module smoke tests and health checks via my.testing)";

    location.enable = lib.mkEnableOption "location services (timezone, geoclue)";
    battery.enable = lib.mkEnableOption "battery/power management (auto-cpufreq, logind)";

    # ── Power Profiles (GNOME power settings) ─────────────────────────────
    power.desktop.enable = lib.mkEnableOption "desktop power profile (never sleep, no lock)";
    power.laptop.enable = lib.mkEnableOption "laptop power profile (battery-aware, lock on idle)";

    # ── Theming ────────────────────────────────────────────────────────────
    theming.stylix.enable = lib.mkEnableOption "Stylix theming framework";
  };
}
