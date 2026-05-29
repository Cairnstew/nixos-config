# Server Configuration
# See: ../../AGENT.md for configuration conventions
{ flake, ... }:
{
  imports = [
    ./disk-config.nix
    ./configuration.nix
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
  ];

  # Explicitly set hostPlatform to ensure pkgs is available
  nixpkgs.hostPlatform = "x86_64-linux";

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "server";
  nixos-unified.sshTarget = "seanc@server";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    # Role
    server.enable = true;
    development.enable = true;

    # Hardware
    gpu.nvidia-headless.enable = true;
    location.enable = true;
  };

  # ── Home Profiles ───────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    server.enable = true;
    development.enable = true;
  };

  # ── Location ────────────────────────────────────────────────────────────
  my.system.location = {
    timeZone = "America/Chicago";
    latitude = 30.2672;
    longitude = -97.7431;
  };

  # ── NVIDIA Configuration ───────────────────────────────────────────────
  my.services.ollama = {
    gpu.enable = true;
    gpu.type = "nvidia";
    dataDir = "/mnt/data/ollama";
  };

  # ── SSH Access
  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];

  # ── Swap Configuration ───────────────────────────────────────────────────
  swapDevices = [{
    device = "/mnt/data/storage/swapfile";
    size = 32 * 1024; # 32GB
  }];

  # ── Unfree Software ────────────────────────────────────────────────────
  nixpkgs.config = {
    allowUnfree = true;
    cuda.acceptLicense = true;
  };

  # ── VSCode Server ───────────────────────────────────────────────────────
  # Imported via the server module which sets this up
}
