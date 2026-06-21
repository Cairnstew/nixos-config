{ lib, stdenv, fetchurl, buildFHSEnv }:

let
  version = "1.4.2";
  binary = stdenv.mkDerivation {
    pname = "endcord-binary";
    inherit version;
    src = fetchurl {
      url = "https://github.com/sparklost/endcord/releases/download/${version}/endcord-${version}-linux.tar.gz";
      hash = "sha256-JceTyH4bP0PXX5vUpsRYAYMNUKkJN1TdJfEEVQpkqSc=";
    };
    dontUnpack = true;
    dontStrip = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p $out
      tar xzf "$src" -C $out endcord
    '';
  };
in
buildFHSEnv {
  name = "endcord";
  pname = "endcord";
  inherit version;
  runScript = "endcord";
  targetPkgs = pkgs: with pkgs; [ zlib stdenv.cc.cc.lib ];
  extraBuildCommands = ''
    mkdir -p $out/usr/bin
    cp -a ${binary}/endcord $out/usr/bin/endcord
  '';
  meta = {
    description = "Feature-rich TUI Discord client";
    longDescription = ''
      Endcord is a third-party feature rich Discord client, running entirely in terminal.
      It is built with Python and ncurses library, to deliver lightweight yet feature rich experience.
    '';
    homepage = "https://github.com/sparklost/endcord";
    license = lib.licenses.mit;
    mainProgram = "endcord";
    maintainers = [ ];
  };
}
