{ buildNpmPackage, nodejs, lib }:

buildNpmPackage {
  pname = "mcp-server-git";
  version = "1.0.0";
  nodejs = nodejs;

  src = lib.cleanSource ./.;

  npmDepsHash = "sha256-vN+221MUUMY8MBcGqM+42HGvFu0eXJZx6bD6rOpp8us=";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/mcp-server-git
    cp -r dist package.json $out/lib/mcp-server-git/
    cp -r node_modules $out/lib/mcp-server-git/
    cat > $out/bin/mcp-server-git <<EOF
    #!${nodejs}/bin/node
    import('$out/lib/mcp-server-git/dist/index.js');
    EOF
    chmod +x $out/bin/mcp-server-git
    runHook postInstall
  '';

  meta = {
    description = "Git MCP server with Content-Length framing";
    license = lib.licenses.mit;
  };
}
