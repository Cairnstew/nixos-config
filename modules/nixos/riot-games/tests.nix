{ config, lib, ... }:
let
  cfg = config.my.programs.riotGames;
  windowsMenuEntry = ''menuentry "${cfg.windows.bootEntry}"'';
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  #
  # The launcher arms a one-shot GRUB entry, so both the bootloader and the
  # menu entry must exist at eval time. There is deliberately no assertion
  # offering a Wine/Proton alternative: Riot Vanguard is a Windows kernel-mode
  # driver (leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol), so a
  # Wine launch path would only produce a client that dies at Vanguard init.
  assertions = [
    {
      assertion = !cfg.enable || config.boot.loader.grub.enable;
      message = ''
        my.programs.riotGames requires GRUB: the Windows launcher arms a
        one-shot entry with `grub-reboot`, which only exists on a GRUB host
        (boot.loader.grub.enable = true). There is no Wine path — Riot
        Vanguard is a Windows kernel driver.
      '';
    }
    {
      assertion = !cfg.enable || lib.hasInfix windowsMenuEntry config.boot.loader.grub.extraEntries;
      message = ''
        my.programs.riotGames.windows.bootEntry = "${cfg.windows.bootEntry}" does
        not match any `menuentry` in boot.loader.grub.extraEntries. Set it to the
        exact GRUB title of the Windows installation, otherwise the launcher
        would arm a non-existent boot entry.
      '';
    }
  ];
}
