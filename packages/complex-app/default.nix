# =============================================================================
# complex-app/default.nix — Example Complex Application Package
# =============================================================================
# Purpose: Demonstrates a more complex mkDerivation-based package with
#          custom install phase and metadata.
#
# Not in nixpkgs: Example/template package for learning/development.
#
# Note: This is primarily a template/example. The actual app.sh should exist
#       in the same directory for this to build.
# =============================================================================

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
    description = "Example complex application package";
    longDescription = ''
      A demonstration package showing mkDerivation patterns:
      - Custom install phase
      - Wrapper support
      - Proper metadata
      
      This is an example/template. To use: place your app.sh script
      in the same directory and update pname/version accordingly.
    '';
    homepage = "https://github.com/Cairnstew/nixos-config";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    mainProgram = "complex-app";
    maintainers = [ ];
  };
}
