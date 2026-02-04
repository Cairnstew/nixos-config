{ lib, stdenv, makeWrapper }:

stdenv.mkDerivation {
  pname = "complex-app";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp app.sh $out/bin/complex-app
    chmod +x $out/bin/complex-app
  '';

  meta = {
    description = "A more complex application";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
  };
}