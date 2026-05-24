{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.hardware;
in
{
  assertions = [
    {
      assertion = !(cfg.gpu.nvidia.enable && cfg.gpu.mesa.enable);
      message = "Cannot enable both NVIDIA and Mesa GPU profiles simultaneously.";
    }
    {
      assertion = !(cfg.gpu.nvidia.headless && cfg.xserver.enable);
      message = "NVIDIA headless mode is incompatible with X server enable. Set my.hardware.gpu.nvidia.headless = false for desktop use.";
    }
  ];

  systemd.services.graphics-smoke-test = mkIf cfg.graphics.enable {
    description = "Smoke test for graphics stack";
    serviceConfig.Type = "oneshot";
    script = ''
      echo "Graphics stack smoke test:"
      echo "  GPU drivers: ${if cfg.gpu.nvidia.enable then "NVIDIA" else if cfg.gpu.mesa.enable then "Mesa" else if cfg.gpu.amd.enable then "AMD" else "none"}"
      echo "  Vulkan: ${if cfg.vulkan.enable then "enabled" else "disabled"}"
      echo "  X server: ${if cfg.xserver.enable then "enabled" else "disabled"}"
    '';
  };
}
