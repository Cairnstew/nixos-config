{ lib, python3, python3Packages, nix, jq, git, stdenv, makeWrapper }:

stdenv.mkDerivation {
  pname = "mcp-nixos";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    (python3.withPackages (ps: with ps; [
      # MCP SDK would go here if available, otherwise we use stdio protocol directly
    ]))
  ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin $out/libexec
    
    # Install the main Python script
    cp ${./mcp-nixos.py} $out/libexec/mcp-nixos.py
    
    # Create wrapper with all runtime dependencies
    makeWrapper ${python3}/bin/python $out/bin/mcp-nixos \
      --add-flags "$out/libexec/mcp-nixos.py" \
      --prefix PATH : ${lib.makeBinPath [ nix jq git ]}
  '';

  meta = {
    description = "MCP server for Nix/NixOS operations";
    homepage = "https://github.com/Cairnstew/nixos-config";
    license = lib.licenses.mit;
    mainProgram = "mcp-nixos";
  };
}
