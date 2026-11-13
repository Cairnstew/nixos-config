# Service dashboard theming — the whole stylesheet plus the colours the inline
# JS/HTML needs.
#
# dashboard.nix is a plain function file (not a module): it renders the page
# structure and the JS, and takes this module's generated `css` + `colors`. That
# keeps every colour in one place while the HTML stays readable.
#
# `theme.enable = false` falls back to the pre-theming palette, so opting out
# leaves the dashboard looking exactly as it did before.
{ config, lib, ... }:

let
  cfg = config.my.services.proxy;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  color = themeLib.color;

  # The dashboard's own colour vocabulary, mapped onto palette roles.
  fromPalette =
    p:
    {
      background = p.background;
      surface = p.surface;
      surfaceSunken = p.backgroundAlt;
      surfaceHover = p.backgroundElement;
      border = p.border;
      borderHover = p.borderStrong;
      foreground = p.foreground;
      # Three legible steps below the foreground. `foregroundSubtle` (base03) is
      # a surface colour in every base16 scheme, so it is too dark for text:
      # nudge it toward the background instead of using it directly.
      muted = color.mix p.foregroundMuted p.foreground 0.35;
      subtle = p.foregroundMuted;
      faint = color.mix p.foregroundMuted p.background 0.55;
      sectionTitle = p.foregroundMuted;
      accent = p.accent;
      accentSoft = color.mix p.accent p.foreground 0.35;
      accentSofter = color.mix p.accent p.foreground 0.6;
      success = p.success;
      warning = p.warning;
      error = p.error;
      cpuGradient = "linear-gradient(90deg, ${p.accent}, ${p.syntaxKeyword})";
      memGradient = "linear-gradient(90deg, ${p.success}, ${color.darken p.success 0.25})";
      diskGradient = "linear-gradient(90deg, ${p.warning}, ${p.error})";
      gpuGradient = "linear-gradient(90deg, ${p.syntaxKeyword}, ${color.darken p.syntaxKeyword 0.3})";
      gpuMemGradient = "linear-gradient(90deg, ${p.info}, ${color.darken p.info 0.3})";
    };

  # Pre-theming values (the dashboard shipped these literals before the theme
  # side-car existed). Used verbatim when `theme.enable = false`.
  defaults = {
    background = "#0f0f14";
    surface = "#1a1a24";
    surfaceSunken = "#14141d";
    surfaceHover = "#1e1e2e";
    border = "#2a2a38";
    borderHover = "#4a4a6a";
    foreground = "#e0e0e0";
    muted = "#888";
    subtle = "#777";
    faint = "#555";
    sectionTitle = "#aaa";
    accent = "#5a8aff";
    accentSoft = "#9db4ff";
    accentSofter = "#c3d0ff";
    success = "#4ade80";
    warning = "#f59e0b";
    error = "#ef4444";
    cpuGradient = "linear-gradient(90deg, #5a8aff, #7c6aff)";
    memGradient = "linear-gradient(90deg, #4ade80, #22c55e)";
    diskGradient = "linear-gradient(90deg, #f59e0b, #ef4444)";
    gpuGradient = "linear-gradient(90deg, #a855f7, #7c3aed)";
    gpuMemGradient = "linear-gradient(90deg, #38bdf8, #2563eb)";
  };

  renderCss =
    c:
    ''
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        background: ${c.background};
        color: ${c.foreground};
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 3rem 1rem;
      }
      .container { max-width: 800px; width: 100%; }
      h1 { font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }
      p.subtitle { color: ${c.muted}; margin-bottom: 2rem; font-size: 0.95rem; }
      .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem; }
      a.card {
        display: block;
        background: ${c.surface};
        border: 1px solid ${c.border};
        border-radius: 10px;
        padding: 1.25rem;
        text-decoration: none;
        color: inherit;
        transition: border-color 0.2s, transform 0.15s;
      }
      a.card:hover { border-color: ${c.borderHover}; transform: translateY(-2px); }
      a.card h2 { font-size: 1.1rem; font-weight: 500; margin-bottom: 0.25rem; }
      a.card .path { font-family: "SF Mono", monospace; font-size: 0.8rem; color: ${c.accent}; }
      a.card .desc { font-size: 0.8rem; color: ${c.subtle}; margin-top: 0.4rem; }
      .footer { margin-top: 3rem; font-size: 0.75rem; color: ${c.faint}; }
      .section-title { font-size: 1.1rem; font-weight: 600; margin: 2rem 0 1rem; color: ${c.sectionTitle}; text-transform: uppercase; letter-spacing: 0.05em; }
      .metrics-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; margin-bottom: 1rem; }
      .metric-card { background: ${c.surface}; border: 1px solid ${c.border}; border-radius: 10px; padding: 1rem; }
      .metric-label { font-size: 0.8rem; color: ${c.muted}; margin-bottom: 0.4rem; text-transform: uppercase; letter-spacing: 0.04em; }
      .metric-bar-bg { height: 8px; background: ${c.border}; border-radius: 4px; overflow: hidden; }
      .metric-bar-fill { height: 100%; border-radius: 4px; transition: width 1s ease; background: ${c.cpuGradient}; }
      .metric-value { font-size: 1.3rem; font-weight: 700; margin-top: 0.4rem; }
      .metrics-info { display: flex; flex-wrap: wrap; gap: 1.5rem; font-size: 0.85rem; color: ${c.subtle}; margin-top: 1rem; padding: 1rem; background: ${c.surface}; border: 1px solid ${c.border}; border-radius: 10px; }
      .metrics-info span { white-space: nowrap; }
      .oc-instance { background: ${c.surface}; border: 1px solid ${c.border}; border-radius: 10px; padding: 1rem; display: flex; flex-direction: column; gap: 0.6rem; }
      .oc-instance .oc-sessions { display: flex; flex-direction: column; gap: 0.25rem; }
      .oc-session { font-size: 0.8rem; color: ${c.accentSoft}; text-decoration: none; padding: 0.2rem 0.4rem; border-radius: 6px; background: ${c.surfaceSunken}; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .oc-session:hover { background: ${c.surfaceHover}; color: ${c.accentSofter}; }
      .oc-empty { font-size: 0.8rem; color: ${c.faint}; }
    '';
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.services.proxy.dashboard.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      let
        c = if config.enable then fromPalette config.palette else defaults;
      in
      {
        colors = lib.mkOption {
          type = lib.types.attrs;
          readOnly = true;
          default = c;
          defaultText = lib.literalExpression "dashboard colour names mapped from my.theming.colors, or the pre-theming palette when disabled";
          description = ''
            Colour names the dashboard's HTML and inline JS interpolate
            (`background`, `surface`, `accent`, `success`, the progress-bar
            gradients, …). Read by dashboard.nix through `theme.colors`.
          '';
        };

        css = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          default = renderCss c;
          defaultText = lib.literalExpression "generated from the dashboard colours";
          description = "The generated stylesheet body (dashboard.nix wraps it in `<style>`).";
        };
      };
  };
}
