{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.zed-editor;
  prefs = flake.config.preferences or { };

  # Resolved palette (modules/home/theming). Zed's theme extension format wants
  # bare 6-digit hex with no "#", which is exactly what `base16` already is —
  # this module used to strip the prefix at all 73 call sites.
  theme = config.my.theming.colors or { };
  b = theme.base16 or { };
  term = theme.terminal or { };
  color = theme.color or { };

  # Pure connection builders — shared with tests.nix.
  remote = import ./remote.nix { inherit lib; };

  # Wrap a hex string in HighlightStyleContent struct
  mkHighlight = c: { color = c; };

  # Auto-generate a Zed theme from the resolved palette.
  # Format: each theme file is a Zed theme extension manifest with a "themes" array
  # See https://zed.dev/docs/extensions/themes
  #
  # Appearance follows the active scheme's polarity rather than
  # `preferences.darkMode`, so the two cannot disagree.
  generatedTheme =
    if theme ? slug then {
      "${theme.slug}" = {
        name = theme.slug;
        author = "auto-generated from my.theming.colors (${theme.family})";
        themes = [
          {
            name = theme.slug;
            appearance = if theme.polarity == "dark" then "dark" else "light";
            style = {
              background = b.base00;
              foreground = b.base05;
              borders = b.base03;
              border = b.base03;
              drop_target = b.base0D;
              element = b.base02;
              element_active = b.base03;
              panel = {
                background = b.base01;
                border = b.base03;
                footer = {
                  background = b.base01;
                  border = b.base03;
                };
                header = {
                  background = b.base01;
                  border = b.base03;
                };
              };
              editor = {
                background = b.base00;
                foreground = b.base05;
                invisible = b.base03;
                line_wrap_guide = b.base03;
                active_line = b.base01;
                highlight_row_background = b.base01;
                bracket_matching = b.base02;
                gutter = {
                  background = b.base00;
                  foreground = b.base04;
                };
              };
              syntax = {
                comment = mkHighlight (b.base03);
                keyword = mkHighlight (b.base0E);
                function = mkHighlight (b.base0D);
                variable = mkHighlight (b.base05);
                string = mkHighlight (b.base0B);
                number = mkHighlight (b.base0F);
                type = mkHighlight (b.base0A);
                operator = mkHighlight (b.base0C);
                punctuation = mkHighlight (b.base05);
                constant = mkHighlight (b.base0F);
                tag = mkHighlight (b.base08);
                attribute = mkHighlight (b.base0D);
                embedded = mkHighlight (b.base0C);
                link_text = mkHighlight (b.base0D);
                link_uri = mkHighlight (b.base0D);
                markup = {
                  bold = {
                    color = b.base0E;
                    font_weight = 700;
                  };
                  italic = {
                    color = b.base09;
                    font_style = "italic";
                  };
                  strikethrough = mkHighlight (b.base03);
                  quote = mkHighlight (b.base03);
                  heading = {
                    color = b.base0D;
                    font_weight = 700;
                  };
                  list = mkHighlight (b.base0C);
                  raw_inline = mkHighlight (b.base0B);
                  raw_block = mkHighlight (b.base01);
                };
              };
              status_bar = {
                background = b.base01;
                foreground = b.base05;
              };
              title_bar = {
                background = b.base00;
                foreground = b.base05;
              };
              scrollbar = {
                thumb = {
                  background = b.base03;
                  border = b.base03;
                };
                track = {
                  background = b.base00;
                  border = b.base00;
                };
              };
              tab = {
                active_background = b.base01;
                active_foreground = b.base05;
                inactive_background = b.base00;
                inactive_foreground = b.base04;
              };
              terminal = {
                background = b.base00;
                foreground = b.base05;
                # The 16 ANSI slots, from the shared terminal palette.
                # These two entries used to be the hardcoded literals "585b70"
                # and "a6adc8" — Catppuccin Mocha and Frappé values respectively,
                # so they disagreed with the rest of the block and would have
                # survived a scheme switch as stale colours.
                ansi = map color.toBase16 [
                  term.black
                  term.red
                  term.green
                  term.yellow
                  term.blue
                  term.magenta
                  term.cyan
                  term.white
                  term.brightBlack
                  term.brightRed
                  term.brightGreen
                  term.brightYellow
                  term.brightBlue
                  term.brightMagenta
                  term.brightCyan
                  term.brightWhite
                ];
              };
            };
          }
        ];
      };
    } else { };

  # Merge user customThemes on top of generated theme (user overrides win)
  mergedThemes = lib.recursiveUpdate generatedTheme cfg.customThemes;

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
    theme = if builtins.isString cfg.theme then cfg.theme else cfg.theme.dark;

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

      themes = mergedThemes;
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
