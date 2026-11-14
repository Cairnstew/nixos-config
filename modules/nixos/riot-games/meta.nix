{
  name = "riot-games";
  description = "Riot Games Windows-only titles (League of Legends, Teamfight Tactics) — one-shot dual-boot launcher plus scrcpy mirroring of the Android TFT client. No Wine path: Riot Vanguard is a Windows kernel driver.";
  category = "gaming";
  tags = [
    "gaming"
    "riot"
    "league-of-legends"
    "teamfight-tactics"
    "vanguard"
    "anticheat"
    "windows"
    "dualboot"
    "scrcpy"
  ];
  provides = [ "my.programs.riotGames" ];
  expects = [ "boot.loader.grub" ];
  complexity = "simple";
  tested = true;
  homepage = "https://leagueoflegends.com";
}
