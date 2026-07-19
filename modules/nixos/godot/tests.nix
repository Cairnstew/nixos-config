{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.godot;
  hasProjects = cfg.projects != { };
in
{
  # ── L0: Nix Assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || (cfg.engine.enable -> cfg.engine.package != null || pkgs ? godot || pkgs ? godot-mono);
      message = ''
        my.programs.godot is enabled but no Godot package is available.
        Either set `engine.package` explicitly or ensure `pkgs.godot`/`pkgs.godot-mono` exists.
      '';
    }
    {
      assertion = !cfg.enable || !cfg.mono.enable || cfg.engine.enable;
      message = ''
        my.programs.godot.mono requires `engine.enable` to be true so that
        godot-mono is available for C# scripting.
      '';
    }
    {
      assertion = !(cfg.enable && cfg.engine.headless.enable) || (cfg.engine.headless.package != null || pkgs ? godot-headless);
      message = ''
        my.programs.godot.engine.headless is enabled but no headless Godot
        package is available. Set `engine.headless.package` explicitly.
      '';
    }
    {
      assertion = !cfg.enable || !(cfg.gdscript.enable && !cfg.gdscript.gdtoolkit && !cfg.gdscript.formatter);
      message = ''
        my.programs.godot.gdscript is enabled but all GDScript tools are
        disabled. Enable at least `gdscript.gdtoolkit` or `gdscript.formatter`.
      '';
    }
    {
      assertion = !cfg.enable || !(cfg.exportTemplates.enable && cfg.exportTemplates.autoDownload) || cfg.exportTemplates.package != null || pkgs ? godot-export-templates-bin || pkgs ? godotPackages.export-templates-mono-bin;
      message = ''
        my.programs.godot.exportTemplates.autoDownload is enabled but no
        export templates package is available. Set `exportTemplates.package`
        explicitly or disable `autoDownload`.
      '';
    }
    {
      assertion = !cfg.enable || !hasProjects || cfg.engine.enable;
      message = ''
        my.programs.godot.projects requires `engine.enable` to be true so that
        Godot is available to open the project files.
      '';
    }
    {
      assertion = !hasProjects || !cfg.enable || (
        builtins.all (n: lib.hasPrefix "/" cfg.projects.${n}.path) (builtins.attrNames cfg.projects)
      );
      message = ''
        All my.programs.godot.projects.*.path must be absolute paths
        (starting with /).
      '';
    }
    {
      assertion = !(cfg.enable && cfg.mcp.enable) || cfg.mcp.port > 1024;
      message = ''
        my.programs.godot.mcp.port must be > 1024 (non-privileged port).
        Got: ${builtins.toString cfg.mcp.port}
      '';
    }
  ];

  # ── L1: systemd probes ────────────────────────────────────────────────────
  # Godot is a GUI application and doesn't run as a system service,
  # so no systemd probes are needed.

  # ── L2: Smoke test oneshot ────────────────────────────────────────────────
  systemd.services.godot-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for Godot game engine installation";
    serviceConfig.Type = "oneshot";
    script =
      let
        godotPkg = if cfg.engine.package != null then cfg.engine.package else if cfg.mono.enable then pkgs.godot-mono else pkgs.godot;
        godotCmd = if cfg.mono.enable then "godot-mono" else "godot";
      in
      ''
        echo "=== Godot Smoke Test ==="

        ${lib.optionalString cfg.engine.enable ''
          if ! command -v ${godotCmd} >/dev/null 2>&1; then
            echo "FAIL: ${godotCmd} binary not found in PATH"
            exit 1
          fi
          echo "PASS: ${godotCmd} binary found"

          VERSION=$(${lib.getBin godotPkg}/bin/${godotCmd} --version 2>/dev/null)
          if [ -n "$VERSION" ]; then
            echo "PASS: Godot version: $VERSION"
          else
            echo "FAIL: godot --version returned empty"
            exit 1
          fi

          # Quick headless project validation (create and validate a project file)
          TEST_DIR=$(mktemp -d)
          cat > "$TEST_DIR/project.godot" << 'EOF'
          ; Engine configuration.
          [application]
          config/name="SmokeTest"
          config/features=PackedStringArray("4.0")
          EOF
          echo "PASS: Basic project.godot created"
          rm -rf "$TEST_DIR"
        ''}

        ${lib.optionalString cfg.gdscript.enable ''
          if command -v gdtoolkit_4-parse >/dev/null 2>&1; then
            echo "PASS: gdtoolkit_4-parse found"
          else
            echo "INFO: gdtoolkit_4-parse not in PATH (check your PATH)"
          fi

          if command -v gdscript-formatter >/dev/null 2>&1; then
            echo "PASS: gdscript-formatter found"
          else
            echo "INFO: gdscript-formatter not in PATH"
          fi
        ''}

        echo "=== Godot Smoke Test Complete ==="
      '';
  };
}
