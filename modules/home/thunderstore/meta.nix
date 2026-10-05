{
  name = "thunderstore";
  description = ''
    Hash-pinned ThunderStore mod packs, installed into the Steam game directory
    discovered from Steam's own configuration (libraryfolders.vdf +
    appmanifest_<appid>.acf). Models the Thunderstore ecosystem: games,
    communities, distributions, the 13 loaders, install rules and tracking
    methods, dependency closure and per-destination install layouts.
  '';
  category = "gaming";
  tags = [
    "gaming"
    "mods"
    "thunderstore"
    "steam"
    "bepinex"
    "melonloader"
  ];
  provides = [
    "my.programs.thunderstore"
    "my.programs.thunderstore.enable"
    "my.programs.thunderstore.packs"
  ];
  complexity = "complex";
  tested = true;
}
