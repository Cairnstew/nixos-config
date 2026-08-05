# ── Ollama MCP wrapper package ────────────────────────────────────────────────
# F9e: this buildNpmPackage expression previously lived inline in
# modules/nixos/ollama/services.nix (~line 9). It belongs in a packages file per
# AGENT.md §2. It is a package expression (a function, NOT a NixOS module), so
# it is deliberately NOT added to default.nix's `imports` — that list must only
# contain modules, and a module here would fail with an unknown-option error.
# services.nix imports it directly via `import ./packages.nix { inherit pkgs; }`,
# which keeps the reference point (ollamaMcpWrapper) identical.
{ pkgs, ... }:
let
  # Wrapper that runs supergateway → ollama-mcp-server for Cline; consumed by
  # the `ollama-mcp-server` systemd unit in services.nix.
  ollamaMcpWrapper = pkgs.buildNpmPackage {
    pname = "ollama-mcp-wrapper";
    version = "1.0.0";
    nodejs = pkgs.nodejs_22;
    src = pkgs.runCommand "ollama-mcp-wrapper-src" { } ''
      mkdir -p $out
      cp ${pkgs.writeText "package.json" (builtins.toJSON {
        name = "ollama-mcp-wrapper";
        version = "1.0.0";
        dependencies = {
          "ollama-mcp-server" = "1.1.0";
          "supergateway" = "3.4.3";
        };
      })} $out/package.json
      cp ${./mcp-package-lock.json} $out/package-lock.json
    '';
    npmDepsHash = "sha256-2q0ImcLtkJmtHTGnEfCYG/g0n7ysUWe7g00qncNSwmA=";
    dontNpmBuild = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules
      cp -r . $out/lib/node_modules/ollama-mcp-wrapper
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/supergateway \
        --add-flags "$out/lib/node_modules/ollama-mcp-wrapper/node_modules/supergateway/dist/index.js"
      runHook postInstall
    '';
  };
in
{
  # Consumed by services.nix (`ollama-mcp-server` unit).
  inherit ollamaMcpWrapper;
}
