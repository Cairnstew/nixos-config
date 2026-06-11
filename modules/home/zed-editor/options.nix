{ lib, pkgs, flake, ... }:

let
  types = lib.types;
  prefs = flake.config.preferences or { };
  scheme = flake.config.me.colorScheme or { };
in
{
  options.my.programs.zed-editor = {

    # ── Core ──────────────────────────────────────────────────────────────────

    enable = lib.mkEnableOption "Zed editor";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.zed-editor;
      defaultText = lib.literalExpression "pkgs.zed-editor";
      description = "The zed-editor package to use.";
    };

    defaultEditor = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to set zed as the default editor via EDITOR/VISUAL env vars.";
    };

    installRemoteServer = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to symlink Zed's remote server binary for remote connections.";
    };

    enableMcpIntegration = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to forward MCP server configs from programs.mcp into Zed's context_servers.";
    };

    mutableUserSettings = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether Zed can overwrite settings.json (if false, Nix is source of truth).";
    };

    mutableUserKeymaps = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether Zed can overwrite keymap.json.";
    };

    mutableUserTasks = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether Zed can overwrite tasks.json.";
    };

    mutableUserDebug = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether Zed can overwrite debug.json.";
    };

    extraPackages = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages to make available to Zed (e.g. LSP servers, formatters).";
    };

    # ── Extensions ────────────────────────────────────────────────────────────

    extensions = lib.mkOption {
      type = types.listOf types.str;
      default = [ "nix" "rust" "toml" "yaml" ];
      description = "Zed extensions to install on startup. Use the extension's repository name.";
      example = [ "nix" "rust" "toml" "yaml" "json" "markdown-preview" "html" "css" ];
    };

    # ── Appearance ────────────────────────────────────────────────────────────

    theme = lib.mkOption {
      type = types.either types.str (types.submodule {
        options = {
          dark = lib.mkOption {
            type = types.str;
            description = "Theme name for dark mode.";
          };
          light = lib.mkOption {
            type = types.str;
            description = "Theme name for light mode.";
          };
          mode = lib.mkOption {
            type = types.enum [ "dark" "light" "system" ];
            default = if prefs.darkMode or true then "dark" else "light";
            description = "Which theme mode to use.";
          };
        };
      });
      default = scheme.slug or "catppuccin-mocha";
      description = ''
        Theme to use. Can be a string (single theme) or an attrset with dark/light variants.
        Defaults from me.colorScheme.slug.
      '';
    };

    customThemes = lib.mkOption {
      type = types.attrsOf types.raw;
      default = { };
      description = ''
        Custom Zed theme definitions. A Catppuccin Mocha theme is auto-generated from
        me.colorScheme when available. Add your own themes here or override the generated one.
      '';
    };



    fontFamily = lib.mkOption {
      type = types.str;
      default = prefs.terminalFont or "JetBrainsMono Nerd Font";
      description = "Default font family for the editor.";
    };

    fontSize = lib.mkOption {
      type = types.int;
      default = 14;
      description = "Default font size for the editor.";
    };

    uiFontSize = lib.mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Font size for the UI. Defaults to fontSize if null.";
    };

    bufferFontSize = lib.mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Font size for editor buffers. Defaults to fontSize if null.";
    };

    terminalFontFamily = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Font family for the terminal panel. Defaults to fontFamily if null.";
    };

    terminalFontSize = lib.mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Font size for the terminal panel. Defaults to fontSize if null.";
    };

    # ── Editor Behavior ──────────────────────────────────────────────────────

    vimMode = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable Vim mode (modal editing).";
    };

    relativeLineNumbers = lib.mkOption {
      type = types.enum [ "disabled" "enabled" "wrapped" ];
      default = "disabled";
      description = "Use relative line numbers. Options: disabled, enabled, or wrapped.";
    };

    tabSize = lib.mkOption {
      type = types.int;
      default = 4;
      description = "Number of spaces per tab.";
    };

    softWrap = lib.mkOption {
      type = types.either types.bool (types.enum [ "editor_width" "preferred_line_length" "bounded" "off" ]);
      default = false;
      description = "Soft wrap behaviour for editor buffers.";
    };

    preferredLineLength = lib.mkOption {
      type = types.int;
      default = 100;
      description = "Preferred line length for line length guides and soft wrap.";
    };

    formatOnSave = lib.mkOption {
      type = types.enum [ "off" "on" "code_actions_only" ];
      default = "on";
      description = "Whether to format files on save.";
    };

    removeTrailingWhitespaceOnSave = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to remove trailing whitespace on save.";
    };

    ensureFinalNewlineOnSave = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to ensure a final newline on save.";
    };

    autosave = lib.mkOption {
      type = types.enum [ "off" "after_delay" "on_focus_change" "on_window_change" ];
      default = "after_delay";
      description = "When to autosave files.";
    };

    autosaveDelay = lib.mkOption {
      type = types.int;
      default = 1000;
      description = "Delay in milliseconds before autosave triggers (only when autosave is after_delay).";
    };

    cursorShape = lib.mkOption {
      type = types.enum [ "bar" "block" "underline" "hollow" ];
      default = "bar";
      description = "Cursor shape for the editor.";
    };

    cursorBlinking = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether the cursor blinks.";
    };

    scrollPastEnd = lib.mkOption {
      type = types.enum [ "off" "one_page" "vertical_scroll_margin" ];
      default = "one_page";
      description = "Whether to allow scrolling past the end of the file. Options: off, one_page, or vertical_scroll_margin.";
    };

    showWhitespaces = lib.mkOption {
      type = types.enum [ "all" "selection" "none" "boundary" ];
      default = "selection";
      description = "When to show whitespace characters.";
    };

    indentGuides = lib.mkOption {
      type = types.either types.bool (types.enum [ "enabled" "disabled" "coloring_only" ]);
      default = true;
      description = "Render indent guides.";
    };

    inlayHints = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Show inline type hints and parameter names from the LSP.";
    };

    confirmQuit = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to prompt before closing the application.";
    };

    restoreSessions = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Restore previous session on startup.";
    };

    # ── Git ───────────────────────────────────────────────────────────────────

    git = {
      gutter = lib.mkOption {
        type = types.enum [ "tracked_files" "all_files" "hide" ];
        default = "tracked_files";
        description = "Which files to show git gutter indicators for.";
      };

      inlineBlame = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Show git blame inline.";
      };

      inlineBlameDelay = lib.mkOption {
        type = types.int;
        default = 500;
        description = "Delay in ms before showing inline blame.";
      };
    };

    # ── Terminal ──────────────────────────────────────────────────────────────

    terminal = {
      alternateScroll = lib.mkOption {
        type = types.enum [ "on" "off" ];
        default = "on";
        description = "Use alternate scroll mode in terminal.";
      };

      blinking = lib.mkOption {
        type = types.enum [ "off" "terminal_controlled" "on" ];
        default = "terminal_controlled";
        description = "Cursor blinking behavior in terminal.";
      };

      copyOnSelect = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Automatically copy selected text to clipboard.";
      };

      shell = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Shell path for the terminal panel (e.g. /run/current-system/sw/bin/zsh).";
      };

      env = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Extra environment variables for the terminal panel.";
        example = { TERM = "xterm-256color"; };
      };
    };

    # ── Language Server ───────────────────────────────────────────────────────

    lspLogLevel = lib.mkOption {
      type = types.enum [ "error" "warning" "info" "debug" "trace" ];
      default = "error";
      description = "Log level for LSP servers.";
    };

    enableLspPolling = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable polling for LSP server file changes (useful for NixOS).";
    };

    # ── Pass-through ──────────────────────────────────────────────────────────

    extraSettings = lib.mkOption {
      type = types.attrs;
      default = { };
      description = "Additional Zed settings merged into userSettings. Overrides typed options.";
      example = {
        features = {
          inline_completion_provider = "supermaven";
        };
        show_nav_history_buttons = false;
      };
    };

    userKeymaps = lib.mkOption {
      type = types.listOf types.anything;
      default = [{ }];
      description = "Zed keymap configuration (keymap.json). HM writes this file when non-empty.";
      example = [
        {
          context = "Editor";
          bindings = { "ctrl-shift-p" = "editor::ToggleComments"; };
        }
      ];
    };

    userTasks = lib.mkOption {
      type = types.listOf types.anything;
      default = [ ];
      description = "Zed task configuration (tasks.json).";
    };

    userDebug = lib.mkOption {
      type = types.listOf types.anything;
      default = [ ];
      description = "Zed debug configuration (debug.json).";
    };
  };
}
