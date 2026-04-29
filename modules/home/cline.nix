# modules/home/cline.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.my.programs.cline;

  # Node 22 required by kanban and cline CLI.
  nodejs = pkgs.nodejs_22;

  # Find the first model flagged as the cline default.
  defaultModelTag = lib.findFirst
    (tag: cfg.ollamaModels.${tag}.cline_default or false)
    null
    (lib.attrNames cfg.ollamaModels);

  usingOllama = cfg.ollamaModels != {};

  # Prefer the flagged Ollama model, then the explicit model option.
  clineDefaultModel =
    if defaultModelTag != null
    then defaultModelTag
    else cfg.model;

  # Build the VS Code settings fragment that Cline reads.
  clineSettings =
    {
      "cline.apiProvider"   = "ollama";
      "cline.ollamaBaseUrl" = cfg.ollamaBaseURL;
      "cline.ollamaModelId" = clineDefaultModel;
    }
    // cfg.settings;

in
{
  options.my.programs.cline = {
    enable = mkEnableOption "Cline – AI coding agent in VS Code";

    # ── Ollama integration ─────────────────────────────────────────────────

    ollamaModels = mkOption {
      type    = types.attrsOf types.anything;
      default = {};
      example = literalExpression ''
        {
          "qwen2.5-coder:14b" = { cline_default = true; };
          "codestral:22b"     = {};
          "mistral:7b"        = {};
        }
      '';
      description = ''
        Ollama models to expose to Cline.
        Set <literal>cline_default = true</literal> on exactly one model to use
        it as the active model; otherwise <option>model</option> is used.
      '';
    };

    ollamaBaseURL = mkOption {
      type    = types.str;
      default = "http://127.0.0.1:11434";
      example = "http://my-gpu-box:11434";
      description = ''
        Base URL for the Ollama server.  Written into VS Code settings as
        <literal>cline.ollamaBaseUrl</literal> and exported as
        <envar>OLLAMA_HOST</envar>.
      '';
    };

    # ── Shorthand options ──────────────────────────────────────────────────

    model = mkOption {
      type    = types.str;
      default = "";
      example = "qwen2.5-coder:14b";
      description = ''
        Fallback model tag when no entry in <option>ollamaModels</option> has
        <literal>cline_default = true</literal>.
      '';
    };

    # ── VS Code settings pass-through ──────────────────────────────────────

    settings = mkOption {
      type    = types.attrsOf types.anything;
      default = {};
      example = literalExpression ''
        {
          "cline.maxTokens"               = 16384;
          "cline.terminalOutputLineLimit" = 500;
        }
      '';
      description = ''
        Extra key/value pairs merged into the Cline VS Code settings fragment.
        Keys must be fully-qualified VS Code setting names
        (i.e. <literal>"cline.*"</literal>).  Values here take precedence over
        all shorthand options above.
      '';
    };

    vsCodeSettingsPath = mkOption {
      type    = types.str;
      default = ".config/Code/User/settings.json";
      example = ".config/VSCodium/User/settings.json";
      description = ''
        Path relative to <envar>HOME</envar> for the VS Code
        <filename>settings.json</filename> file.  Override for VS Code OSS,
        VSCodium, or a non-standard XDG base directory.
      '';
    };

    # ── Kanban CLI ─────────────────────────────────────────────────────────

    kanban = {
      enable = mkOption {
        type    = types.bool;
        default = false;
        description = ''
          Install the <command>cline-kanban</command> CLI — a browser-based
          kanban board for orchestrating multiple coding agents in parallel
          via git worktrees.  Run <command>cline-kanban</command> from the
          root of any git repo to open the board in your browser.

          The <literal>kanban</literal> npm package is installed into
          <filename>~/.npm-global</filename> on first <command>home-manager
          switch</command> and kept there across rebuilds.
        '';
      };

      extraArgs = mkOption {
        type    = types.listOf types.str;
        default = [];
        example = literalExpression ''[ "--host" "0.0.0.0" "--port" "3484" ]'';
        description = ''
          Extra command-line flags passed to <command>kanban</command> on
          every invocation.  Use <literal>--host 0.0.0.0</literal> to bind
          to all interfaces when running on a remote machine or WSL.
        '';
      };
    };
  };

  # ── Implementation ─────────────────────────────────────────────────────────
  config = mkIf cfg.enable {

    assertions = [
      {
        assertion =
          let
            defaults = lib.filter
              (tag: cfg.ollamaModels.${tag}.cline_default or false)
              (lib.attrNames cfg.ollamaModels);
          in
          builtins.length defaults <= 1;
        message = ''
          my.programs.cline.ollamaModels: at most one model may have
          `cline_default = true`.
        '';
      }
      {
        assertion = usingOllama -> clineDefaultModel != "";
        message = ''
          my.programs.cline: ollamaModels is non-empty but no default model
          could be determined.  Either set `cline_default = true` on one
          model or set `my.programs.cline.model`.
        '';
      }
    ];

    # ── Kanban CLI package ─────────────────────────────────────────────────

    home.packages = lib.optional cfg.kanban.enable (
      pkgs.writeShellScriptBin "cline-kanban" ''
        export NPM_CONFIG_PREFIX=$HOME/.npm-global
        exec ${lib.getExe nodejs} $HOME/.npm-global/bin/kanban \
          ${lib.escapeShellArgs cfg.kanban.extraArgs} \
          "$@"
      ''
    );

    # Install/upgrade the kanban npm package into ~/.npm-global on every
    # home-manager switch.  npm install -g is idempotent when already current.
    home.activation.installKanban = lib.mkIf cfg.kanban.enable (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            export NPM_CONFIG_PREFIX=$HOME/.npm-global
            export PATH=${nodejs}/bin:${pkgs.python3}/bin:${pkgs.gcc}/bin:${pkgs.gnumake}/bin:$PATH
            $DRY_RUN_CMD ${nodejs}/bin/npm install -g kanban
        ''
        );

    # ── VS Code settings ───────────────────────────────────────────────────

    # Preferred path: let home-manager's vscode module own settings.json.
    programs.vscode.userSettings = mkIf
      (config.programs.vscode.enable or false)
      clineSettings;

    # Fallback: write a standalone settings.json when vscode is not HM-managed.
    home.file."${cfg.vsCodeSettingsPath}" = mkIf
      (!(config.programs.vscode.enable or false))
      {
        text  = builtins.toJSON clineSettings;
        force = false;
      };

    # ── Environment ────────────────────────────────────────────────────────

    home.sessionVariables =
      optionalAttrs usingOllama {
        OLLAMA_HOST = cfg.ollamaBaseURL;
      }
      // optionalAttrs cfg.kanban.enable {
        # Ensure npm -g always resolves to the writable prefix, not the
        # read-only Nix store, for any manual npm -g commands the user runs.
        NPM_CONFIG_PREFIX = "$HOME/.npm-global";
      };
  };
}