{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "foundation-save-export-mod";
  version = "1.0.0";

  src = lib.cleanSource ./.;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/foundation/mods/foundation-save-export
    cp $src/mod.json $out/share/foundation/mods/foundation-save-export/
    cp $src/mod.lua $out/share/foundation/mods/foundation-save-export/
    cp -r $src/scripts $out/share/foundation/mods/foundation-save-export/
    runHook postInstall
  '';

  meta = {
    description = "Foundation mod that exports game state to JSON for save management and analysis";
    longDescription = ''
      Press F12 in-game to export all game objects, their components, and game stats
      to a timestamped JSON file in the mod's output directory.
    '';
    homepage = "https://github.com/anomalyco/nixos-config";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
