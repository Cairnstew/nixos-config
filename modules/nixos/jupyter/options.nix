{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.jupyter = {
    enable = mkEnableOption "Jupyter notebook server with per-project uv-managed environments";

    user = mkOption {
      type = types.str;
      default = "jupyter";
      description = "System user under which the Jupyter server runs.";
    };

    group = mkOption {
      type = types.str;
      default = "jupyter";
      description = "System group under which the Jupyter server runs.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/jupyter/projects";
      description = ''
        Base directory holding per-project repos. Each subdirectory containing
        <literal>pyproject.toml</literal> + <literal>uv.lock</literal> is
        automatically discovered and registered as a Jupyter kernel.
        New projects are added by cloning a repo under this path — no
        nixos-config edit required.
      '';
    };

    pythonPackage = mkOption {
      type = types.package;
      default = pkgs.python312;
      defaultText = lib.literalExpression "pkgs.python312";
      description = ''
        Python interpreter used by <literal>uv</literal> to create per-project
        virtual environments. Pinned via <literal>UV_PYTHON</literal> to
        prevent uv from downloading its own interpreter.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8888;
      description = "Port number the Jupyter server listens on.";
    };

    ip = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP address the Jupyter server binds to.";
    };

    openFirewall = mkEnableOption "open the Jupyter server port in the firewall";

    jupyterPackage = mkOption {
      type = types.package;
      default = pkgs.python3.pkgs.jupyter;
      defaultText = lib.literalExpression "pkgs.python3.pkgs.jupyter";
      description = "Jupyter package providing the server binary.";
    };

    uvPackage = mkOption {
      type = types.package;
      default = pkgs.uv;
      defaultText = lib.literalExpression "pkgs.uv";
      description = "uv package for creating/syncing per-project virtual environments.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.python3.pkgs.ipykernel ]";
      description = "Extra packages available in the Jupyter server environment.";
    };
  };
}
