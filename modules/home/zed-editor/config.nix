{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.zed-editor;
  scheme = flake.config.me.colorScheme or { };
  prefs = flake.config.preferences or { };
  inherit (lib) removePrefix;

  # Wrap a hex string in HighlightStyleContent struct
  mkHighlight = c: { color = c; };

  # Auto-generate a Catppuccin Mocha theme from me.colorScheme
  # Format: each theme file is a Zed theme extension manifest with a "themes" array
  # See https://zed.dev/docs/extensions/themes
  generatedTheme =
    if scheme ? base00 then {
      "${scheme.slug}" = {
        name = scheme.slug;
        author = "auto-generated from flake.config.me.colorScheme";
        themes = [
          {
            name = scheme.slug;
            appearance = if prefs.darkMode or true then "dark" else "light";
            style = {
              background = removePrefix "#" scheme.base00;
              foreground = removePrefix "#" scheme.base05;
              borders = removePrefix "#" scheme.base03;
              border = removePrefix "#" scheme.base03;
              drop_target = removePrefix "#" scheme.base0D;
              element = removePrefix "#" scheme.base02;
              element_active = removePrefix "#" scheme.base03;
              panel = {
                background = removePrefix "#" scheme.base01;
                border = removePrefix "#" scheme.base03;
                footer = {
                  background = removePrefix "#" scheme.base01;
                  border = removePrefix "#" scheme.base03;
                };
                header = {
                  background = removePrefix "#" scheme.base01;
                  border = removePrefix "#" scheme.base03;
                };
              };
              editor = {
                background = removePrefix "#" scheme.base00;
                foreground = removePrefix "#" scheme.base05;
                invisible = removePrefix "#" scheme.base03;
                line_wrap_guide = removePrefix "#" scheme.base03;
                active_line = removePrefix "#" scheme.base01;
                highlight_row_background = removePrefix "#" scheme.base01;
                bracket_matching = removePrefix "#" scheme.base02;
                gutter = {
                  background = removePrefix "#" scheme.base00;
                  foreground = removePrefix "#" scheme.base04;
                };
              };
              syntax = {
                comment = mkHighlight (removePrefix "#" scheme.base03);
                keyword = mkHighlight (removePrefix "#" scheme.base0E);
                function = mkHighlight (removePrefix "#" scheme.base0D);
                variable = mkHighlight (removePrefix "#" scheme.base05);
                string = mkHighlight (removePrefix "#" scheme.base0B);
                number = mkHighlight (removePrefix "#" scheme.base0F);
                type = mkHighlight (removePrefix "#" scheme.base0A);
                operator = mkHighlight (removePrefix "#" scheme.base0C);
                punctuation = mkHighlight (removePrefix "#" scheme.base05);
                constant = mkHighlight (removePrefix "#" scheme.base0F);
                tag = mkHighlight (removePrefix "#" scheme.base08);
                attribute = mkHighlight (removePrefix "#" scheme.base0D);
                embedded = mkHighlight (removePrefix "#" scheme.base0C);
                link_text = mkHighlight (removePrefix "#" scheme.base0D);
                link_uri = mkHighlight (removePrefix "#" scheme.base0D);
                markup = {
                  bold = {
                    color = removePrefix "#" scheme.base0E;
                    font_weight = 700;
                  };
                  italic = {
                    color = removePrefix "#" scheme.base09;
                    font_style = "italic";
                  };
                  strikethrough = mkHighlight (removePrefix "#" scheme.base03);
                  quote = mkHighlight (removePrefix "#" scheme.base03);
                  heading = {
                    color = removePrefix "#" scheme.base0D;
                    font_weight = 700;
                  };
                  list = mkHighlight (removePrefix "#" scheme.base0C);
                  raw_inline = mkHighlight (removePrefix "#" scheme.base0B);
                  raw_block = mkHighlight (removePrefix "#" scheme.base01);
                };
              };
              status_bar = {
                background = removePrefix "#" scheme.base01;
                foreground = removePrefix "#" scheme.base05;
              };
              title_bar = {
                background = removePrefix "#" scheme.base00;
                foreground = removePrefix "#" scheme.base05;
              };
              scrollbar = {
                thumb = {
                  background = removePrefix "#" scheme.base03;
                  border = removePrefix "#" scheme.base03;
                };
                track = {
                  background = removePrefix "#" scheme.base00;
                  border = removePrefix "#" scheme.base00;
                };
              };
              tab = {
                active_background = removePrefix "#" scheme.base01;
                active_foreground = removePrefix "#" scheme.base05;
                inactive_background = removePrefix "#" scheme.base00;
                inactive_foreground = removePrefix "#" scheme.base04;
              };
              terminal = {
                background = removePrefix "#" scheme.base00;
                foreground = removePrefix "#" scheme.base05;
                ansi = [
                  (removePrefix "#" scheme.base03)
                  (removePrefix "#" scheme.base08)
                  (removePrefix "#" scheme.base0B)
                  (removePrefix "#" scheme.base0A)
                  (removePrefix "#" scheme.base0D)
                  (removePrefix "#" scheme.base0E)
                  (removePrefix "#" scheme.base0C)
                  (removePrefix "#" scheme.base05)
                  "585b70"
                  (removePrefix "#" scheme.base08)
                  (removePrefix "#" scheme.base0B)
                  (removePrefix "#" scheme.base0A)
                  (removePrefix "#" scheme.base0D)
                  (removePrefix "#" scheme.base0E)
                  (removePrefix "#" scheme.base0C)
                  "a6adc8"
                ];
              };
            };
          }
        ];
      };
    } else { };

  # Merge user customThemes on top of generated theme (user overrides win)
  mergedThemes = lib.recursiveUpdate generatedTheme cfg.customThemes;

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

  } // lib.optionalAttrs (lib.attrByPath [ "my" "programs" "opencode" "enable" ] false config) {
    agent_servers = {
      OpenCode = {
        command = "opencode";
        args = [ "acp" ];
      };
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
      userSettings = mergedSettings;
      userKeymaps = cfg.userKeymaps;
      userTasks = cfg.userTasks;
      userDebug = cfg.userDebug;
    };
  };
}
