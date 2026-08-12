{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;
in
{
  options.my.programs.modpack = {
    enable = mkEnableOption "Minecraft modpack engineering tooling (Modrinth MCP, mods/ management)";

    dataDir = mkOption {
      type = types.path;
      default = "${config.xdg.dataHome}/modpack";
      defaultText = literalExpression ''"''${config.xdg.dataHome}/modpack"'';
      description = "Directory for modpack state (patch ledger, cached Modrinth metadata, backups).";
    };

    modsDir = mkOption {
      type = types.path;
      default = "${config.xdg.dataHome}/modpack/mods";
      defaultText = literalExpression ''"''${config.xdg.dataHome}/modpack/mods"'';
      description = "Directory containing the modpack's .jar mod files. May be set to a large drive (e.g. /mnt/media/Modding/mods).";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.jq ]";
      description = "Extra modpack-engineering packages to install alongside the Python MCP runtime.";
    };

    modrinth = {
      baseUrl = mkOption {
        type = types.str;
        default = "https://api.modrinth.com/v2";
        description = "Modrinth API v2 base URL. Override to point at a mirror/proxy or a mock server for tests.";
      };

      userAgent = mkOption {
        type = types.str;
        default = "nixos-config-modpack-mcp/0.1.0 (contact: seanc)";
        description = "User-Agent sent to the Modrinth API. Modrinth requires a descriptive User-Agent; keep the contact field when overriding.";
      };
    };
  };
}
