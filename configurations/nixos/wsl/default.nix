# WSL Configuration
# See: ../../AGENT.md for configuration conventions
{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.common
  ];

  # Explicitly set hostPlatform to ensure pkgs is available
  nixpkgs.hostPlatform = "x86_64-linux";

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "wsl";

  # stateVersion inlined from deleted configuration.nix stub (W2)
  system.stateVersion = "25.11";

  # ── WSL Specific ───────────────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = flake.config.me.username;
    wslConf.network.generateResolvConf = false;
  };

  networking.useHostResolvConf = false;
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" "100.100.100.100" ];
  networking.search = [ "lan" ];

  # ── System Profiles ────────────────────────────────────────────────────
  my.profiles = {
    # Minimal profile for WSL
    minimal.enable = true;
    development.enable = true;
  };

  # ── Home Profiles ───────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    minimal.enable = true;
  };

  # ── Home Manager Extra ─────────────────────────────────────────────────
  my.homeManager.extraConfig.my.programs = {
    obsidian.enable = true;
    vscode.enable = true;
  };

  # ── VS Code Server ─────────────────────────────────────────────────────
  # Required for VS Code Remote-WSL (fixes dynamically linked Node binaries)
  my.programs.vscode.server.enable = true;
}
