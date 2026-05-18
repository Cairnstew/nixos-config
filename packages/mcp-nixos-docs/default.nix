# packages/mcp-nixos-docs/default.nix
{ lib, python3, python3Packages, nix, jq, stdenv, makeWrapper, fetchgit }:

stdenv.mkDerivation {
  pname = "mcp-nixos-docs";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    (python3.withPackages (ps: with ps; [
      requests
      beautifulsoup4
      markdown
    ]))
  ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/libexec
    
    # Install the main Python script
    cp ${./mcp-nixos-docs.py} $out/libexec/mcp-nixos-docs.py
    
    # Create wrapper with all runtime dependencies
    makeWrapper ${python3}/bin/python $out/bin/mcp-nixos-docs \
      --add-flags "$out/libexec/mcp-nixos-docs.py" \
      --prefix PATH : ${lib.makeBinPath [ nix jq ]}
  '';

  meta = {
    description = "MCP server for searching nixos-unified.org documentation";
    homepage = "https://github.com/Cairnstew/nixos-config";
    license = lib.licenses.mit;
    mainProgram = "mcp-nixos-docs";
  };
}
