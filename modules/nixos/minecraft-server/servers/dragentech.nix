# modules/nixos/minecraft-server/servers/dragentech.nix
# DragonTech NeoForge server (DragonTech packwiz pack). Every server in this
# folder is disabled by default — opt in from a host config or a profile, e.g.:
#   my.services.minecraftServer.servers.dragentech.enable = true;
#   my.profiles.gaming.minecraftServers = [ "dragentech" ];
{ lib, pkgs, ... }:
{
  my.services.minecraftServer.servers.dragentech = {
    enable = lib.mkDefault false;

    package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238; # matches DragonTech pack.toml
    packwiz = ../modpacks/DragonTech;
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
    jvmOpts = "-Xmx6G -Xms3G -Dorg.lwjgl.opencl.libname=/run/opengl-driver/lib/libOpenCL.so.1 -XX:+UseG1GC -XX:G1HeapRegionSize=16M";
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

    serverProperties = {
      motd = "A DragonTech Server";
      max-players = 4;
      white-list = false;
    };
    whitelist = { };
    operators = { };
  };
}
