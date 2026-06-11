import { execSync } from "node:child_process";

export default {
  description: "Run 'nix flake check --no-build' to validate the Nix flake configuration. Catches evaluation errors, assertion failures, and missing options before deployment.",
  args: {
    allowWarnings: {
      type: "boolean",
      description: "If true, treat warnings as success. Default: false (warnings count as failure).",
    },
  },
  async execute(args: { allowWarnings?: boolean }) {
    try {
      const flakeDir = process.env.PWD || ".";

      const out = execSync("nix flake check --no-build 2>&1", {
        encoding: "utf-8",
        timeout: 120_000,
        cwd: flakeDir,
        maxBuffer: 10 * 1024 * 1024,
      });

      return `✓ nix flake check passed\n\n${out}`;
    } catch (e: any) {
      const stderr = e.stderr || "";
      const stdout = e.stdout || "";
      const combined = (stdout + stderr).trim();

      // If --allow-warnings, check if there are actual errors or just warnings
      if (args.allowWarnings) {
        const hasErrors = combined.includes("error:") || combined.includes("Error:");
        if (!hasErrors) {
          return `✓ nix flake check passed (with warnings)\n\n${combined}`;
        }
      }

      return `✗ nix flake check failed\n\n${combined}`;
    }
  },
};
