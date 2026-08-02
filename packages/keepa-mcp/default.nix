{ lib, buildNpmPackage, fetchFromGitHub, makeWrapper, nodejs }:

buildNpmPackage rec {
  pname = "keepa-mcp";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "cosjef";
    repo = "keepa_MCP";
    rev = "fcba449314a28f1243ce4114cbf7c545919b60fb";
    hash = "sha256-AvJvjvTefzXZAuYccr7osh0McJidVbDN13sd83XZwqs=";
  };

  npmDepsHash = "sha256-2ejcQfSFSvz0rHGpZBch87KEquu4h1Fsb1vDqYhI8aI=";

  # keepa_mcp ships a compiled dist/ in the repo, but rebuild from source
  # to keep the tree clean and consistent with the lockfile.
  npmBuild = "tsc";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/keepa-mcp \
      --add-flags "$out/lib/node_modules/keepa-mcp-server/dist/index.js"
  '';

  meta = {
    description = "MCP server for Keepa Amazon product intelligence (price history, deals, sellers)";
    homepage = "https://github.com/cosjef/keepa_MCP";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "keepa-mcp";
    maintainers = [ "seanc" ];
  };
}
