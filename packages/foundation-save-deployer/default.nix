{ lib, stdenvNoCC, python3, makeWrapper }:

stdenvNoCC.mkDerivation {
  pname = "foundation-save-deployer";
  version = "1.0.0";

  src = lib.cleanSourceWith {
    filter = name: type:
      let baseName = baseNameOf (toString name);
      in baseName != "meta.nix" && baseName != "default.nix"
    ;
    src = lib.cleanSource ./.;
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/lib/foundation-save-deployer
    mkdir -p $out/share/foundation-save-deployer/templates

    cp -r $src/src/*.py $out/lib/foundation-save-deployer/
    cp -r $src/templates/* $out/share/foundation-save-deployer/templates/

    chmod +x $out/lib/foundation-save-deployer/main.py

    makeWrapper ${python3}/bin/python $out/bin/foundation-save-deployer \
      --add-flags "$out/lib/foundation-save-deployer/main.py"

    runHook postInstall
  '';

  meta = {
    description = "CLI tool to manage, backup, and deploy Foundation game saves";
    longDescription = ''
      Foundation is a medieval city-building game by Polymorph Games (Steam App ID 690830).
      This tool manages save files stored in the game's Proton compat data directory.

      Features:
      - List saves with timestamps, sizes, and backup status
      - Backup and restore save files
      - Create and deploy save templates (starter saves)
      - Auto-detect the Foundation save directory
    '';
    homepage = "https://github.com/polymorph-games/foundation";
    license = lib.licenses.mit;
    mainProgram = "foundation-save-deployer";
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
