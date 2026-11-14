{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.riotGames = {
    enable = mkEnableOption ''
      Riot Games titles that cannot run on Linux (League of Legends, Teamfight
      Tactics, VALORANT). Adds a one-shot "reboot into Windows" launcher and,
      optionally, scrcpy mirroring of the Android TFT client. There is no Wine
      path: Riot Vanguard is a Windows kernel driver and refuses Wine/Proton/VM
    '';

    leagueOfLegends = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Add a desktop entry that sets a one-shot GRUB entry for the Windows
          installation and reboots. League of Legends (and TFT, which shares
          the same client) cannot be launched from Linux — Riot's Vanguard
          anti-cheat is a Windows kernel-mode driver.
        '';
      };
    };

    teamfightTactics = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Add a desktop entry that sets a one-shot GRUB entry for the Windows
          installation and reboots. The TFT desktop client shares the League
          client and therefore the same Vanguard requirement.
        '';
      };
    };

    windows = {
      bootEntry = mkOption {
        type = types.str;
        default = "Windows 11";
        example = "Windows Boot Manager";
        description = ''
          Exact GRUB menu title of the Windows installation. Must match a
          `menuentry` in <option>boot.loader.grub.extraEntries</option>; the
          launcher verifies this before touching the boot environment.
        '';
      };
    };

    mobileMirror = {
      enable = mkEnableOption ''
        scrcpy mirroring of the Android Teamfight Tactics client — the only
        route that still works on Linux (the phone runs the game; the desktop
        only mirrors and forwards input). The Android path via Waydroid is dead
        — the mobile Vanguard (libmvg.so) shipped to the production client on
        2026-08-26 — and the only revival published since (2026-10) ptrace-masks
        the anti-cheat, which is ban risk and is deliberately not shipped here
      '';

      maxSize = mkOption {
        type = types.ints.positive;
        default = 1920;
        description = "scrcpy `--max-size` — long-edge pixel cap of the mirrored video stream.";
      };

      maxFps = mkOption {
        type = types.ints.positive;
        default = 60;
        description = "scrcpy `--max-fps` — frame-rate cap of the mirrored video stream.";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "--audio-codec=aac" ];
        description = "Extra arguments appended to the scrcpy command line.";
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to install system-wide alongside the launchers.";
    };
  };
}
