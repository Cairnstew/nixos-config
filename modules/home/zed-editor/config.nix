{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.zed-editor;
  prefs = flake.config.preferences or { };

  # Pure connection builders — shared with tests.nix.
  remote = import ./remote.nix { inherit lib; };

  # ── SSH Connections (tailnet auto-discovery + explicit) ──────────────
  #
  # All building lives in remote.nix so config.nix and tests.nix exercise the
  # exact same code. The previous inline version generated connections in Zed's
  # snake_case JSON shape but then ran them through a converter that expected
  # the camelCase *option* shape, so `tailnetConnections.enable = true` failed
  # to evaluate with "attribute 'uploadBinaryOverSsh' missing". Nothing enabled
  # the option, so it never surfaced.
  formattedConnections =
    map remote.mkConnection
      (
        remote.buildConnections {
          tailnet = flake.config.tailnet or { };
          username = flake.config.me.username;
          tailnetConnections = cfg.tailnetConnections;
          sshConnections = cfg.sshConnections;
        }
      );

  # Build userSettings from typed options, then merge extraSettings on top
  computedSettings = {
    theme = if builtins.isString cfg.theme.name then cfg.theme.name else cfg.theme.name.dark;

    font_family = cfg.fontFamily;
    font_size = cfg.fontSize;
    ui_font_size = if cfg.uiFontSize != null then cfg.uiFontSize else cfg.fontSize;
    buffer_font_size = if cfg.bufferFontSize != null then cfg.bufferFontSize else cfg.fontSize;
    terminal = {
      font_family = if cfg.terminalFontFamily != null then cfg.terminalFontFamily else cfg.fontFamily;
      font_size = if cfg.terminalFontSize != null then cfg.terminalFontSize else cfg.fontSize;
      alternate_scroll = cfg.terminal.alternateScroll;
      blinking = cfg.terminal.blinking;
      copy_on_select = cfg.terminal.copyOnSelect;
    } // (if cfg.terminal.shell != null then { shell = cfg.terminal.shell; } else { })
    // cfg.terminal.env;

    vim_mode = cfg.vimMode;
    relative_line_numbers = cfg.relativeLineNumbers;
    tab_size = cfg.tabSize;
    soft_wrap =
      if builtins.isBool cfg.softWrap then
        (if cfg.softWrap then "editor_width" else "none")
      else
        cfg.softWrap;
    preferred_line_length = cfg.preferredLineLength;
    format_on_save = cfg.formatOnSave;
    remove_trailing_whitespace_on_save = cfg.removeTrailingWhitespaceOnSave;
    ensure_final_newline_on_save = cfg.ensureFinalNewlineOnSave;
    autosave =
      if cfg.autosave == "after_delay" then {
        after_delay = {
          milliseconds = cfg.autosaveDelay;
        };
      } else cfg.autosave;
    cursor_shape = cfg.cursorShape;
    cursor_blink = cfg.cursorBlinking;
    scroll_beyond_last_line = cfg.scrollPastEnd;
    show_whitespaces = cfg.showWhitespaces;
    indent_guides = { enabled = cfg.indentGuides; coloring = "fixed"; };
    inlay_hints = { enabled = cfg.inlayHints; };
    confirm_quit = cfg.confirmQuit;
    restore_on_startup = if cfg.restoreSessions then "last_session" else "none";

    git = {
      git_gutter = cfg.git.gutter;
      inline_blame = {
        enabled = cfg.git.inlineBlame;
        delay_ms = cfg.git.inlineBlameDelay;
      };
    };

  } // lib.optionalAttrs (formattedConnections != [ ]) {
    ssh_connections = formattedConnections;
  } // lib.optionalAttrs (lib.attrByPath [ "my" "programs" "opencode" "enable" ] false config) {
    agent_servers = {
      OpenCode = {
        command = "opencode";
        args = [ "acp" ];
      };
    };
  } // lib.optionalAttrs cfg.enableNotebooks {
    # WIP Jupyter notebook support — feature flag (see options.nix).
    feature_flags = {
      notebooks = "on";
    };
  };

  mergedSettings = lib.recursiveUpdate computedSettings cfg.extraSettings;
in
{
  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      inherit (cfg) package;
      defaultEditor = cfg.defaultEditor;
      installRemoteServer = cfg.installRemoteServer;
      enableMcpIntegration = cfg.enableMcpIntegration;
      extensions = cfg.extensions;
      extraPackages = cfg.extraPackages;

      mutableUserSettings = cfg.mutableUserSettings;
      mutableUserKeymaps = cfg.mutableUserKeymaps;
      mutableUserTasks = cfg.mutableUserTasks;
      mutableUserDebug = cfg.mutableUserDebug;

      userSettings = lib.mkDefault mergedSettings;
      userKeymaps = cfg.userKeymaps;
      userTasks = cfg.userTasks;
      userDebug = cfg.userDebug;
    };

    # ── Notebooks (WIP feature flag, see options.nix) ──────────────────────
    # Both the settings feature flag AND the env var are required; the env var
    # must reach the process actually launching Zed: environment.d (picked up
    # by systemd user sessions / GUI launches), home.sessionVariables (shell
    # launches), and the devShell/`nix run .` wrapper set it too.
    home.sessionVariables = lib.mkIf cfg.enableNotebooks {
      LOCAL_NOTEBOOK_DEV = "1";
    };

    # ~/.config/environment.d/zed-notebooks.conf — systemd environment.d is the
    # reliable channel for GUI apps on Hyprland/session launches (a plain
    # shell sessionVariable does not reach processes started by the compositor).
    xdg.configFile."environment.d/zed-notebooks.conf" = lib.mkIf cfg.enableNotebooks {
      text = "LOCAL_NOTEBOOK_DEV=1\n";
    };
  };
}
