{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;
in
{
  options.my.programs.cv = {
    enable = mkEnableOption "CV content MCP server (thin CRUD over the Cairnstew/CV sqlite store)";

    dataDir = mkOption {
      type = types.path;
      default = "${config.xdg.dataHome}/cv";
      defaultText = literalExpression ''"''${config.xdg.dataHome}/cv"'';
      description = "Directory for the SQLite database and persistent state.";
    };
  };
}