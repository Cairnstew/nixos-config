# VS Code theming — derives workbench + token colours from the shared palette.
#
# No theme extension is generated: `workbench.colorCustomizations` and
# `editor.tokenColorCustomizations` override any base theme, which is both
# simpler and lets the user keep a built-in base theme for colours we do not
# map. This replaces the previous hardcoded Dracula theme/extension.
{ config, lib, ... }:

let
  cfg = config.my.programs.vscode;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  color = themeLib.color;

  # `alpha` produces #rrggbbaa, which VS Code accepts for these keys.
  a = hex: opacity: color.alpha hex opacity;

  mkSettings =
    p:
    let
      term = p.terminal;
    in
    {
      "workbench.colorCustomizations" = {
        # Editor
        "editor.background" = p.background;
        "editor.foreground" = p.foreground;
        "editorCursor.foreground" = p.cursor;
        "editor.selectionBackground" = p.selection;
        "editor.selectionHighlightBackground" = a p.selection 0.6;
        "editor.lineHighlightBackground" = p.surface;
        "editorLineNumber.foreground" = p.foregroundSubtle;
        "editorLineNumber.activeForeground" = p.foreground;
        "editorIndentGuide.background1" = p.borderSubtle;
        "editorIndentGuide.activeBackground1" = p.border;
        "editorWhitespace.foreground" = p.borderSubtle;
        "editorGutter.background" = p.background;
        "editorBracketMatch.background" = p.surface;
        "editorBracketMatch.border" = p.accent;
        "editor.findMatchBackground" = a p.accent 0.35;
        "editor.findMatchHighlightBackground" = a p.accent 0.2;
        "editor.wordHighlightBackground" = a p.accent 0.25;
        "editorError.foreground" = p.error;
        "editorWarning.foreground" = p.warning;
        "editorInfo.foreground" = p.info;
        "editorHint.foreground" = p.success;
        "editorHoverWidget.background" = p.surface;
        "editorHoverWidget.border" = p.border;
        "editorSuggestWidget.background" = p.surface;
        "editorSuggestWidget.border" = p.border;
        "editorSuggestWidget.selectedBackground" = p.accent;
        "editorSuggestWidget.selectedForeground" = p.background;

        # Chrome
        "sideBar.background" = p.surface;
        "sideBar.foreground" = p.foreground;
        "sideBar.border" = p.borderSubtle;
        "sideBarSectionHeader.background" = p.background;
        "activityBar.background" = p.background;
        "activityBar.foreground" = p.foreground;
        "activityBar.border" = p.borderSubtle;
        "activityBarBadge.background" = p.accent;
        "activityBarBadge.foreground" = p.background;
        "statusBar.background" = p.surface;
        "statusBar.foreground" = p.foreground;
        "statusBar.noFolderBackground" = p.surface;
        "statusBar.debuggingBackground" = p.warning;
        "statusBar.debuggingForeground" = p.background;
        "titleBar.activeBackground" = p.background;
        "titleBar.activeForeground" = p.foreground;
        "titleBar.inactiveBackground" = p.surface;
        "titleBar.inactiveForeground" = p.foregroundMuted;
        "tab.activeBackground" = p.background;
        "tab.activeForeground" = p.foreground;
        "tab.inactiveBackground" = p.surface;
        "tab.inactiveForeground" = p.foregroundMuted;
        "tab.border" = p.borderSubtle;
        "editorGroupHeader.tabsBackground" = p.surface;
        "editorGroupHeader.tabsBorder" = p.borderSubtle;
        "panel.background" = p.background;
        "panel.border" = p.borderSubtle;
        "panelTitle.activeForeground" = p.foreground;

        # Lists / controls
        "list.activeSelectionBackground" = p.accent;
        "list.activeSelectionForeground" = p.background;
        "list.inactiveSelectionBackground" = p.backgroundElement;
        "list.hoverBackground" = p.surface;
        "button.background" = p.accent;
        "button.foreground" = p.background;
        "button.hoverBackground" = p.accentAlt;
        "input.background" = p.background;
        "input.foreground" = p.foreground;
        "input.border" = p.border;
        "input.placeholderForeground" = p.foregroundSubtle;
        "dropdown.background" = p.surface;
        "dropdown.border" = p.border;
        "dropdown.foreground" = p.foreground;
        "focusBorder" = p.accent;
        "badge.background" = p.accent;
        "badge.foreground" = p.background;
        "selection.background" = a p.selection 0.8;
        "menu.background" = p.surface;
        "menu.foreground" = p.foreground;
        "menu.selectionBackground" = a p.accent 0.3;
        "scrollbarSlider.background" = a p.border 0.6;
        "scrollbarSlider.hoverBackground" = a p.border 0.8;
        "scrollbarSlider.activeBackground" = p.border;
        "widget.shadow" = a p.background 0.5;

        # Peek / diff / git
        "peekView.border" = p.accent;
        "peekViewEditor.background" = p.background;
        "peekViewResult.background" = p.surface;
        "diffEditor.insertedTextBackground" = a p.success 0.2;
        "diffEditor.removedTextBackground" = a p.error 0.2;
        "gitDecoration.addedResourceForeground" = p.success;
        "gitDecoration.modifiedResourceForeground" = p.warning;
        "gitDecoration.deletedResourceForeground" = p.error;
        "gitDecoration.untrackedResourceForeground" = p.info;
        "gitDecoration.ignoredResourceForeground" = p.foregroundSubtle;

        # Integrated terminal
        "terminal.background" = p.background;
        "terminal.foreground" = p.foreground;
        "terminalCursor.foreground" = p.cursor;
        "terminal.selectionBackground" = p.selection;
        "terminal.ansiBlack" = term.black;
        "terminal.ansiRed" = term.red;
        "terminal.ansiGreen" = term.green;
        "terminal.ansiYellow" = term.yellow;
        "terminal.ansiBlue" = term.blue;
        "terminal.ansiMagenta" = term.magenta;
        "terminal.ansiCyan" = term.cyan;
        "terminal.ansiWhite" = term.white;
        "terminal.ansiBrightBlack" = term.brightBlack;
        "terminal.ansiBrightRed" = term.brightRed;
        "terminal.ansiBrightGreen" = term.brightGreen;
        "terminal.ansiBrightYellow" = term.brightYellow;
        "terminal.ansiBrightBlue" = term.brightBlue;
        "terminal.ansiBrightMagenta" = term.brightMagenta;
        "terminal.ansiBrightCyan" = term.brightCyan;
        "terminal.ansiBrightWhite" = term.brightWhite;
      };

      "editor.tokenColorCustomizations" = {
        "textMateRules" = [
          {
            scope = [ "comment" "punctuation.definition.comment" ];
            settings = {
              foreground = p.syntaxComment;
              fontStyle = "italic";
            };
          }
          {
            scope = [ "keyword" "storage" "storage.type" "storage.modifier" ];
            settings.foreground = p.syntaxKeyword;
          }
          {
            scope = [ "entity.name.function" "support.function" "meta.function-call" ];
            settings.foreground = p.syntaxFunction;
          }
          {
            scope = [ "string" "constant.other.symbol" ];
            settings.foreground = p.syntaxString;
          }
          {
            scope = [ "constant.numeric" "constant.language" ];
            settings.foreground = p.syntaxNumber;
          }
          {
            scope = [ "entity.name.type" "entity.name.class" "support.type" "support.class" ];
            settings.foreground = p.syntaxType;
          }
          {
            scope = [ "keyword.operator" ];
            settings.foreground = p.syntaxOperator;
          }
          {
            scope = [ "variable" "meta.definition.variable" ];
            settings.foreground = p.foreground;
          }
          {
            scope = [ "variable.parameter" ];
            settings.foreground = p.error;
          }
          {
            scope = [ "entity.name.tag" ];
            settings.foreground = p.error;
          }
          {
            scope = [ "entity.other.attribute-name" ];
            settings.foreground = p.syntaxFunction;
          }
          {
            scope = [ "invalid" "invalid.illegal" ];
            settings.foreground = p.error;
          }
        ];
      };
    };
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.vscode.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        baseTheme = lib.mkOption {
          type = lib.types.str;
          default =
            if config.palette.polarity == "dark" then "Default Dark Modern" else "Default Light Modern";
          description = ''
            Base VS Code theme. The generated `workbench.colorCustomizations`
            and token colours are layered on top, so this only supplies the
            keys the palette does not map.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          readOnly = true;
          default = mkSettings config.palette;
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = ''
            The generated `settings.json` fragment (colour theme, workbench
            customizations, token colours). config.nix merges it under the
            user's `userSettings`.
          '';
        };
      };
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    # `mkDefault`: stylix's vscode target sets its own palette-derived base
    # theme when it is active (and keeps the font/chrome settings). Our colour
    # customizations layer on top either way.
    programs.vscode.profiles.default.userSettings."workbench.colorTheme" =
      lib.mkDefault t.baseTheme;
  };
}
