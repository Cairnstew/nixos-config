# modules/nixos/minecraft-server/servers/prominence.nix
# Prominence II: Hasturian Era — Fabric 1.20.1 dedicated server.
# A premade Modrinth modpack (lore-rich RPG, custom Talent Tree, artifact
# weapons, boss fights), fetched declaratively via fetchModrinthModpack at
# build time and wired through the `pack` option (see options.nix). Every
# server in this folder is disabled by default — opt in from a host config:
#   my.services.minecraftServer.servers.prominence.enable = true;
{ lib, pkgs, ... }:
{
  my.services.minecraftServer.servers.prominence = {
    enable = lib.mkDefault false;

    # Prominence II is a Fabric 1.20.1 pack, so the server runs the Fabric
    # loader server for 1.20.1 (matches the pack's pack format / MC version).
    package = pkgs.fabricServers.fabric-1_20_1;

    # Fetch the latest Prominence II Fabric mrpack from Modrinth at build time
    # (hash-verified, reproducible, works on fresh machines). `side = "server"`
    # auto-filters client-only mods (shaders, some UI/render mods) out of the
    # downloaded set, and applies the pack's server-overrides on top.
    pack = pkgs.fetchModrinthModpack {
      pname = "prominence-2-fabric";
      version = "4.0.1hf";
      url = "https://cdn.modrinth.com/data/EGs3lC8D/versions/VIPL0GhM/Prominence%E2%84%A2%20II%20Hasturian%20Era%204.0.1hf.mrpack";
      packHash = "sha256-k7hNwL0PkStuWqrF/gQGEXSpstoM8S7FXpLRS9mC10o=";
      side = "server";
    };

    # Heap sized for the server host (15Gi RAM total, shared with other
    # services — see hardware caps below). Fabric is lighter than NeoForge, so
    # 6G heap + 3G start leaves headroom. G1GC under 16G heap per c2me-ocl's
    # FAQ guidance (ZGC only worthwhile above 16G).
    jvmOpts = "-Xmx6G -Xms3G -XX:+UseG1GC -XX:G1HeapRegionSize=16M -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=40 -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:+UseStringDeduplication -XX:G1MixedGCCountTarget=8 -XX:+DisableExplicitGC";
    port = 25565;
    autoStart = true;

    # Resource caps so a runaway server can't OOM the host (which also runs
    # opencode-web, backup, monitoring, etc.).
    hardware = {
      memoryHigh = "7G";
      memoryMax = "10G";
      memorySwapMax = "2G";
      nice = 5;
    };

    serverProperties = {
      motd = "A Prominence II Server";
      max-players = 2; # pack is designed for two players
      white-list = false;
      view-distance = 8;
      simulation-distance = 6;
      max-tick-time = -1;
      network-compression-threshold = 512;
      entity-broadcast-range-percentage = 75;
      max-chained-neighbor-updates = 1000;
    };
    whitelist = { };
    operators = { };
  };
}
