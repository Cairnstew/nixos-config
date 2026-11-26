{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.vscode;
in
{
  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = lib.mkIf (cfg.package != null) cfg.package;
      profiles.default = {
        extensions = cfg.extensions
          ++ cfg.additionalExtensions
          ++ lib.optional cfg.continue.enable pkgs.vscode-extensions.continue.continue;
        # Generated palette first, user settings win on conflict.
        userSettings = lib.recursiveUpdate cfg.theme.settings cfg.userSettings;
        inherit (cfg) keybindings globalSnippets languageSnippets;
        # Shared MCP registry (programs.mcp.servers) from the host config.
        enableMcpIntegration = cfg.mcp.enable;
        # Nix-managed install: neither VS Code nor its extensions can update
        # themselves, so suppress the notifications. mkDefault keeps a host
        # free to opt back in.
        enableUpdateCheck = lib.mkDefault false;
        enableExtensionUpdateCheck = lib.mkDefault false;
      };
    };

    home.file.".continue/config.yaml" = lib.mkIf cfg.continue.enable {
      text =
        let
          baseConfig = {
            models = map
              (model: {
                name = model;
                provider = "ollama";
                inherit model;
                apiBase = cfg.continue.ollamaHost;
              })
              cfg.continue.models;
          };
          mergedConfig = lib.recursiveUpdate baseConfig cfg.continue.extraConfig;
        in
        builtins.readFile (
          (pkgs.formats.yaml { }).generate "continue-config" mergedConfig
        );
    };
  };
}
