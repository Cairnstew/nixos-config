{ lib, stdenvNoCC, python3, makeWrapper }:

stdenvNoCC.mkDerivation {
  pname = "foundation-save-cli";
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
    mkdir -p $out/lib/foundation-save-cli

    cp -r $src/src/*.py $out/lib/foundation-save-cli/

    mkdir -p $out/lib/foundation-save-cli/moddev
    cp $src/moddev/init.lua $out/lib/foundation-save-cli/moddev/init.lua

    chmod +x $out/lib/foundation-save-cli/main.py

    makeWrapper ${python3}/bin/python $out/bin/foundation-save-cli \
      --add-flags "$out/lib/foundation-save-cli/main.py"

    runHook postInstall
  '';

  meta = {
    description = "CLI tool to parse, generate, and modify Foundation game saves and connect to the running game at runtime";
    longDescription = ''
      Foundation is a medieval city-building game by Polymorph Games (Steam App ID 690830).
      This CLI tool parses, generates, and modifies .foundation save files and connects
      to the running game via a TCP server (Lua moddev).

      Features:
      - Parse .foundation save files (header, thumbnail, binary blob)
      - Extract and inject thumbnails
      - Inspect save file metadata
      - Connect to Foundation's Lua moddev TCP server at runtime
    '';
    homepage = "https://store.steampowered.com/app/690830/Foundation/";
    license = lib.licenses.mit;
    mainProgram = "foundation-save-cli";
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
