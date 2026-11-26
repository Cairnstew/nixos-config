{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.vscode;
in
{
  options.my.programs.vscode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Visual Studio Code with custom configuration";
    };

    server = {
      enable = lib.mkEnableOption ''
        VS Code server support for Remote-SSH/WSL development.
        Note: This option only has an effect on NixOS hosts that import
        the corresponding NixOS module (nixosModules.vscode-server).
        On standalone Home Manager it is a no-op.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression "pkgs.vscode";
      description = ''
        VS Code build to install; `null` uses Home Manager's default
        (`pkgs.vscode`). Must be a VS Code build, not a fork: forks get their
        own Home Manager module (`programs.vscodium`, `programs.cursor`, …)
        because they write to different data directories.
      '';
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs.vscode-extensions; [
        ms-python.python
        ms-toolsai.jupyter
        # Maintained Nix language support; the old `bbenoist.nix` extension is
        # archived upstream and its LSP wiring no longer works.
        jnoortheen.nix-ide
        # .envrc support — the repo's dev shells are direnv-driven.
        mkhl.direnv
        ms-vscode-remote.vscode-remote-extensionpack
      ];
      description = "VSCode extensions to install";
    };

    additionalExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional VSCode extensions to install (merged with defaults)";
    };

    userSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        # ── Editor & Code Quality ──────────────────────────────────────────
        "editor.formatOnSave" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll.eslint" = "explicit";
        };
        "files.insertFinalNewline" = true;
        "files.trimTrailingWhitespace" = true;

        # ── Visuals & UI Polish ────────────────────────────────────────────
        "workbench.sideBar.location" = "right";
        "editor.cursorBlinking" = "smooth";
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.rulers" = [ 80 120 ];
        "editor.renderWhitespace" = "selection";
        "breadcrumbs.enabled" = true;

        # ── File & Explorer Management ─────────────────────────────────────
        "editor.wordWrap" = "on";
        "files.exclude" = {
          "**/.git" = true;
          "**/.DS_Store" = true;
          "**/node_modules" = true;
        };
        "files.watcherExclude" = {
          "**/node_modules/**" = true;
        };

        # ── Integrated Terminal ────────────────────────────────────────────
        "terminal.integrated.wordWrap" = true;
        "terminal.integrated.cursorBlinking" = true;
        "terminal.integrated.copyOnSelection" = true;

        # ── Language-Specific ──────────────────────────────────────────────
        "[markdown]" = {
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = {
            "comments" = "on";
            "strings" = "on";
            "other" = "on";
          };
        };
        "workbench.iconTheme" = "vs-minimal";

        # ── Nix (jnoortheen.nix-ide) ───────────────────────────────────────
        # Absolute store paths: nothing puts nixd/nixpkgs-fmt on the user PATH,
        # and the extension otherwise fails to start its language server. Same
        # pairing the repo already uses for Zed (nixd + nixpkgs-fmt).
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
        "nix.serverSettings.nixd.formatting.command" = [ "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt" ];
        "nix.formatterPath" = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
        };

        # ── direnv (mkhl.direnv) ───────────────────────────────────────────
        # Load the workspace `.envrc` (here `use flake`, so the repo devShell)
        # into terminals and the extension host. The executable path is pinned
        # so a GUI-launched VS Code does not need direnv on its PATH.
        "direnv.path.executable" = "${pkgs.direnv}/bin/direnv";
        # Without this the extension host keeps the pre-.envrc environment
        # (formatters, LSPs, tasks) after the devShell loads.
        "direnv.restart.automatic" = true;
      };
      description = "VS Code user settings (settings.json).";
    };

    keybindings = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      example = lib.literalExpression ''
        [
          { key = "ctrl+shift+p"; command = "workbench.action.showCommands"; }
          { key = "ctrl+k"; command = "workbench.action.files.saveAll"; when = "editorFocus"; }
        ]
      '';
      description = ''
        Keybindings written to VS Code's `keybindings.json`. Each entry needs
        at least `key` and `command`; `when` and `args` are optional.
      '';
    };

    globalSnippets = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Global user snippets (`global.code-snippets`).";
    };

    languageSnippets = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Per-language user snippets, keyed by language id.";
    };

    mcp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Forward the servers declared in Home Manager's `programs.mcp.servers`
          into VS Code's `mcp.json` (`profiles.default.enableMcpIntegration`).
          NixOS hosts get the shared server registry from
          `modules/nixos/homeManager/config.nix`; set this to `false` to keep
          VS Code's MCP config independent of it.
        '';
      };
    };

    continue = {
      enable = lib.mkEnableOption "Continue AI coding assistant";

      ollamaHost = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
        description = "Ollama API base URL.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "llama3.2" "mistral" ];
        description = "Ollama models to expose to Continue.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Extra configuration to merge into ~/.continue/config.yaml.
          See https://docs.continue.dev/reference for all options.
        '';
        example = lib.literalExpression ''
          {
            tabAutocompleteModel = {
              name = "starcoder2";
              provider = "ollama";
              model = "starcoder2:3b";
            };
            slashCommands = [
              { name = "share"; description = "Export conversation"; }
            ];
          }
        '';
      };
    };
  };
}
