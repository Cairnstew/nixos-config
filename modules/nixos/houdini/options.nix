{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.my.programs.houdini;
in
{
  options.my.programs.houdini = {
    enable = mkEnableOption "SideFX Houdini 3D animation software";

    package = mkOption {
      type = types.package;
      default = pkgs.houdini;
      defaultText = lib.literalExpression "pkgs.houdini";
      description = "The Houdini package to install.";
    };

    licenseServer = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "license-server.local:1715";
      description = ''
        Houdini license server address in `host:port` format.
        When set, configures the `sesi_license` environment and
        license client files to point to a remote license server
        instead of requiring a local `sesinetd` daemon.
        Mutually exclusive with `localLicenseServer.enable`.
      '';
    };

    localLicenseServer = {
      enable = mkEnableOption "SideFX's sesinetd local license server daemon (listens on port 1715)";
    };

    redeemNonCommercial = {
      enable = mkEnableOption "automatic 30-day renewal of Houdini Apprentice (NC) licenses via the SideFX License API (enables localLicenseServer automatically)";

      serverCode = mkOption {
        type = types.str;
        description = ''
          Server code from `sesictrl print-server`. Run this once after the
          first `sesinetd` start and paste the value here — it is your
          sesinetd instance's unique identifier and only changes on reinstall.

          Obtain it with:

          ```bash
          sudo sesictrl print-server
          ```

          or from the License Administrator GUI (Help → Diagnostics).
        '';
      };

      serverName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = "Server name sent to the SideFX License API. Defaults to the system hostname.";
      };

      version = mkOption {
        type = types.str;
        default = lib.versions.majorMinor cfg.package.passthru.unwrapped.version;
        defaultText = lib.literalExpression ''
          lib.versions.majorMinor cfg.package.passthru.unwrapped.version
        '';
        example = "22.0";
        description = "Houdini major.minor version to request licenses for.";
      };

      products = mkOption {
        type = types.listOf types.str;
        default = [ "HOUDINI-NC" "RENDER-NC" ];
        example = [ "HOUDINI-NC" ];
        description = ''
          Non-commercial products to license. Defaults to both Houdini-NC
          and Render-NC so each Apprentice install gets the full toolset.
        '';
      };
    };

    extraEnv = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        HOUDINI_TEMP_DIR = "/mnt/scratch/houdini_temp";
      };
      description = ''
        Extra environment variables to set for Houdini sessions.
        These are added to the user's profile via
        `environment.sessionVariables`.
      '';
    };

    opencode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Register the Houdini MCP server and skills into the PRIMARY user's
          global opencode config (`my.programs.opencode`). The MCP entry lands
          alongside the other module MCPs (cv/goals/modpack); the skills render
          into `~/.config/opencode/skills/` and load in any project. Inert on
          hosts where opencode is not enabled for the primary user.
        '';
      };

      skills = mkOption {
        type = types.attrsOf types.str;
        description = ''
          Custom opencode skills contributed by this module (name → SKILL.md
          markdown). Knowledge skills for working with Houdini — HOM/hou Python
          + hython, VEX, HDA anatomy + hotl, .hip file format, command-line
          rendering (husk/mantra/hrender), and hscript — useful whether or not
          a live Houdini is present.
        '';
        default = {
          houdini-hou-python = builtins.readFile ./opencode/skills/houdini-hou-python.md;
          houdini-vex = builtins.readFile ./opencode/skills/houdini-vex.md;
          houdini-hda = builtins.readFile ./opencode/skills/houdini-hda.md;
          houdini-hip-format = builtins.readFile ./opencode/skills/houdini-hip-format.md;
          houdini-rendering = builtins.readFile ./opencode/skills/houdini-rendering.md;
          houdini-hscript = builtins.readFile ./opencode/skills/houdini-hscript.md;
        };
        example = lib.literalExpression ''
          { "houdini-vex" = builtins.readFile ./opencode/skills/houdini-vex.md; }
        '';
      };

      mcp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Add a local MCP server entry to the global opencode MCP config.";
        };
        name = mkOption {
          type = types.str;
          default = "fxhoudini";
          description = "MCP server name in the opencode config.";
        };
        host = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = ''
            Houdini hwebserver host the bridge connects to. The bridge can run
            arbitrary Python inside your Houdini session — keep this loopback
            and never expose Houdini's hwebserver beyond loopback.
          '';
        };
        port = mkOption {
          type = types.port;
          default = 8100;
          description = "Houdini hwebserver port (the fxhoudinimcp plugin's default is 8100).";
        };
        timeout = mkOption {
          type = types.int;
          default = 120000;
          description = "MCP server startup timeout in ms. Note fxhoudinimcp's own bridge calls hard-code a 60 s per-request timeout (upstream issue #38).";
        };
        command = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Command (+ args) that starts the MCP server. Empty (default) =
            `uvx --from fxhoudinimcp fxhoudinimcp` — healkeiser/fxhoudinimcp,
            the most maintained Houdini MCP (MIT, pure-Python stdio bridge to
            the plugin running inside a live Houdini session on `host:port`).
            Set your own to use e.g. a Nix-packaged python env:
            `[ "/nix/store/...-fxhoudinimcp/bin/fxhoudinimcp" ]`.
          '';
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Extra environment variables for the MCP server process.";
        };
      };
    };
  };
}
