# modules/nixos/minecraft-server/servers/allthetech.nix
# AllTheTech NeoForge server (AllTheTech packwiz pack). Every server in this
# folder is disabled by default — opt in from a host config or a profile, e.g.:
#   my.services.minecraftServer.servers.allthetech.enable = true;
#   my.profiles.gaming.minecraftServers = [ "allthetech" ];
{ lib, pkgs, ... }:
{
  my.services.minecraftServer.servers.allthetech = {
    enable = lib.mkDefault false;

    package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238; # matches AllTheTech pack.toml
    packwiz = ../modpacks/AllTheTech;
    # Heap sized for the server host (15Gi RAM total, shared with other
    # services — see hardware caps below). Modded NeoForge wants a big heap but
    # the OS + other units need headroom; 6G heap + 3G start is the balance.
    # G1GC (not ZGC): per c2me-ocl's FAQ heap guidance ZGC is only worthwhile
    # above 16G; under that G1 avoids extra native memory.
    # The -Dorg.lwjgl.opencl.libname override and the GPU/OpenCL wiring (ocl-icd
    # in /run/opengl-driver, LD_LIBRARY_PATH, PrivateDevices=false + DeviceAllow)
    # are left DORMANT: c2me-ocl was removed because the NVIDIA 595.80 OpenCL
    # compiler hangs indefinitely (clBuildProgram) on its generated noise kernel
    # — a vendor driver bug, not fixable from config/JVM flags. Re-enable c2me-ocl
    # and this override together if the driver is ever fixed/upgraded.
    # Note: -XX:+UseCompactObjectHeaders was tried while chasing the hang but
    # broke JNI/FFI (java.lang.foreign) — do not re-add.
    #
    # GC tuning for smoother gameplay during Chunky pregen:
    #   - ParallelRefProcEnabled — faster reference processing (common under
    #     heavy allocation like worldgen)
    #   - MaxGCPauseMillis=200 — target pause time; balances throughput vs lag
    #   - G1NewSizePercent=40 — more young gen for allocation bursts (worldgen)
    #   - AlwaysPreTouch — pre-touch heap pages; more consistent latency
    #   - G1HeapWastePercent=5 — less aggressive mixed GC promotion
    #   - UseStringDeduplication — dedupe identical strings (worldgen chunks)
    #   - G1MixedGCCountTarget=8 — spread mixed GCs over more cycles
    #   - DisableExplicitGC — prevent System.gc() calls from mods
    jvmOpts = "-Xmx6G -Xms3G -Dorg.lwjgl.opencl.libname=/run/opengl-driver/lib/libOpenCL.so.1 -XX:+UseG1GC -XX:G1HeapRegionSize=16M -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=40 -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:+UseStringDeduplication -XX:G1MixedGCCountTarget=8 -XX:+DisableExplicitGC";
    port = 25565;
    autoStart = true;

    # Resource caps so a runaway server can't OOM the host (which also runs
    # opencode-web, backup, monitoring, etc.). Soft throttle at 7G, hard cap at
    # 10G, swap capped at 2G to avoid thrashing; server runs at slightly lower
    # scheduling priority than interactive services.
    hardware = {
      memoryHigh = "7G";
      memoryMax = "10G";
      memorySwapMax = "2G";
      nice = 5;
    };

    # Performance-tuned server properties derived from log analysis:
    #   - view-distance=8  (was 10): 36% fewer chunks loaded per player
    #   - simulation-distance=6 (was 10): 64% fewer entities processed
    #   - max-tick-time=-1: disable built-in watchdog (C2ME has its own)
    #   - network-compression-threshold=512 (was 256): less CPU on compression
    #   - entity-broadcast-range-percentage=75 (was 100): less entity network
    #   - max-chained-neighbor-updates=1000 (was 1000000!): redstone spam limiter
    serverProperties = {
      motd = "An AllTheTech Server";
      max-players = 4;
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
