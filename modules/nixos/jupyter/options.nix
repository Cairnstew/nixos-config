{ lib, pkgs, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  username = flake.config.me.username;
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
      default = "/home/${username}/Documents/jupyter_projects";
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

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "config.age.secrets.jupyter-password.path";
      description = ''
        Path to a file containing a bcrypt-hashed password for the Jupyter
        server. When set, token authentication is disabled and password
        login is required. Generate the hash with:
        <literal>python3 -c "from jupyter_server.auth import passwd; print(passwd())"</literal>
      '';
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

    templates = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Directory name for the project.";
          };

          packages = mkOption {
            type = types.listOf types.str;
            default = [ "ipykernel" ];
            example = lib.literalExpression ''[ "ipykernel" "pandas" "matplotlib" ]'';
            description = "Python packages to include in the project's pyproject.toml.";
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Optional project description for pyproject.toml.";
          };
        };
      });
      default = [ ];
      example = lib.literalExpression ''
        [
          { name = "gcu_ai"; packages = [ "ipykernel" "pandas" "scikit-learn" ]; }
          { name = "data_analysis"; packages = [ "ipykernel" "numpy" "matplotlib" ]; }
        ]
      '';
      description = ''
        Template projects to create on every rebuild. Each template gets a
        directory under <literal>dataDir</literal> with a
        <literal>pyproject.toml</literal> and <literal>uv.lock</literal>.
        The Jupyter discover service automatically registers them as kernels.
      '';
    };
  };
}
