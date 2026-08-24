# modules/nixos/projectzomboid-server/modpacks/vanilla-plus.nix
# Example modpack: a small Vanilla+ bundle of well-known Project Zomboid
# Workshop mods. Workshop item IDs come from the individual Steam Workshop page
# URLs (https://steamcommunity.com/sharedfiles/filedetails/?id=<id>) — verify each
# is current for the PZ build you run. The server downloads them all into
# steamapps/workshop/content/108600/ and clients auto-download on join.
#
# Note: modworkshop.net mods are NOT Workshop items — add those as local mods
# (see the `mods` field on a server / modpack) and place their folders in the
# shared install's Zomboid/mods.
{ ... }:
{
  my.services.projectZomboid.modpacks.vanilla-plus = {
    description = "A small Vanilla+ bundle: common QoL and map mods, close to vanilla difficulty.";

    # Steam Workshop item IDs only — the server fills the WorkshopItems= list.
    workshopMods = [
      { id = "2625441155"; title = "Brita's Armor Pack"; }
      { id = "2625840413"; title = "Brita's Weapon Pack"; }
      { id = "2679583791"; title = "Project Zomboid eXpanded Helicopter Events"; }
      { id = "2634209060"; title = "Filibuster Rhymes' Used Cars!"; }
    ];

    # No bundled local mods in this example.
    mods = [ ];

    # Default .ini settings any server using this pack inherits (a server's own
    # `settings` override these).
    defaultSettings = {
      PVP = true;
      PauseEmpty = true;
      SaveWorldEveryMinutes = 10;
    };

    # Default sandbox vars (a server's own `sandbox` override these).
    defaultSandbox = {
      Zombies = 3;            # High
      DayLength = 4;          # 1 Hour, 30 Minutes
      Helicopter = 3;         # Sometimes
      ZombieRespawn = 3;      # Low
      FoodLootNew = 0.8;
      RangedWeaponLootNew = 1.2;
    };
  };
}
