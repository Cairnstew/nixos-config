# Generate pyproject.toml from Nix configuration
{ pkgs, cfg, lib }:
let
  # Build pyproject.toml structure
  attrs = {
    build-system = {
      requires = [ "hatchling>=1.18.0" ];
      build-backend = "hatchling.build.api";
    };

    project = {
      name = cfg.name;
      version = cfg.version;
      description = cfg.description;
      readme = cfg.readme;
      requires-python = cfg.requiresPython;
      dependencies = cfg.dependencies;
      scripts = cfg.scripts;
    } // lib.optionalAttrs (cfg.optionalDependencies != {}) {
      optional-dependencies = cfg.optionalDependencies;
    };

    # Dev dependencies group (PEP 735)
    dependency-groups = lib.optionalAttrs (cfg.devDependencies != []) {
      dev = cfg.devDependencies;
    };

    # Ruff configuration
    tool.ruff = {
      line-length = 100;
      target-version = "py312";
    };

    tool.ruff.lint = {
      select = [ "E" "F" "I" "UP" ];
      ignore = [ "E501" ]; # Line too long (handled by formatter)
    };

    # Pytest configuration
    tool.pytest = lib.optionalAttrs (lib.elem "pytest" cfg.devDependencies) {
      ini_options = {
        testpaths = [ "tests" ];
        python_files = [ "test_*.py" "*_test.py" ];
        python_classes = [ "Test*" ];
        python_functions = [ "test_*" ];
      };
    };

    # Coverage configuration
    tool.coverage = lib.optionalAttrs (lib.elem "pytest-cov" cfg.devDependencies) {
      run = {
        source = [ cfg.name ];
        omit = [ "tests/*" "*/conftest.py" ];
      };
      report = {
        show_missing = true;
        skip_covered = false;
      };
    };
  };

  # Convert to JSON for processing
  jsonData = pkgs.writeText "pyproject-data.json" (builtins.toJSON attrs);

  # Python script to generate TOML
  writerPy = pkgs.writeText "write-pyproject.py" ''
    import json
    import sys
    from pathlib import Path

    def to_toml_value(v, indent=0):
        """Convert Python value to TOML string"""
        if isinstance(v, bool):
            return "true" if v else "false"
        elif isinstance(v, (int, float)):
            return str(v)
        elif isinstance(v, str):
            # Escape special characters
            return json.dumps(v)
        elif isinstance(v, list):
            if not v:
                return "[]"
            # Check if simple list (all primitives)
            if all(isinstance(i, (str, bool, int, float)) for i in v):
                items = [to_toml_value(i) for i in v]
                return "[" + ", ".join(items) + "]"
            # Complex list - use multiline
            lines = ["["]
            for item in v:
                lines.append("    " + to_toml_value(item) + ",")
            lines.append("]")
            return "\n".join(lines)
        elif isinstance(v, dict):
            return None  # Handle dicts as sections
        else:
            return json.dumps(str(v))

    def write_inline_table(out, d, indent=0):
        """Write dict as inline table {key = value, ...}"""
        if not d:
            return "{}"
        items = []
        for k, v in d.items():
            if isinstance(v, dict):
                items.append(f"{k} = {write_inline_table(out, v, indent + 4)}")
            else:
                items.append(f"{k} = {to_toml_value(v)}")
        return "{ " + ", ".join(items) + " }"

    def write_section(out, key, value, indent=0):
        """Recursively write TOML sections"""
        prefix = "    " * indent

        if isinstance(value, dict):
            # Check if this dict contains only simple values (no nested dicts)
            has_nested = any(isinstance(v, dict) for v in value.values())

            if not has_nested and value:
                # Write as inline table if no nested dicts
                out.append(f"{prefix}{key} = {write_inline_table(out, value)}")
            else:
                # Write as section header
                if indent == 0:
                    out.append(f"\n[{key}]")
                else:
                    out.append(f"\n{prefix}[{key}]")

                # Write simple values first
                nested = []
                for k, v in value.items():
                    if isinstance(v, dict):
                        nested.append((k, v))
                    elif v is not None:
                        toml_v = to_toml_value(v)
                        if toml_v is not None:
                            out.append(f"{prefix}{k} = {toml_v}")

                # Then write nested dicts as sub-sections
                for k, v in nested:
                    write_section(out, k, v, indent + 1)
        else:
            toml_v = to_toml_value(value)
            if toml_v is not None:
                out.append(f"{prefix}{key} = {toml_v}")

    def main():
        if len(sys.argv) != 3:
            print(f"Usage: {sys.argv[0]} <input.json> <output.toml>", file=sys.stderr)
            sys.exit(1)

        json_path = sys.argv[1]
        toml_path = sys.argv[2]

        with open(json_path) as f:
            data = json.load(f)

        lines = ["# Generated by flake.nix — edit in modules/flake.nix"]

        for section, value in data.items():
            write_section(lines, section, value)

        output = "\n".join(lines) + "\n"
        Path(toml_path).write_text(output)
        print(f"Generated {toml_path}")

    if __name__ == "__main__":
        main()
  '';

in
{
  inherit jsonData writerPy;
}
