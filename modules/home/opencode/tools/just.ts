import { execSync } from "node:child_process";

export default {
  description: "Run just command recipes. Use 'list' to see all available recipes. Use 'run <recipe>' to execute a specific recipe with optional arguments.",
  args: {
    action: {
      type: "string",
      description: "Either 'list' to show available recipes, or the recipe name to run (e.g. 'check', 'fmt', 'update').",
    },
    arguments: {
      type: "string",
      description: "Additional arguments to pass to the recipe (e.g. hostname for 'test' or 'activate').",
    },
  },
  async execute(args: { action?: string; arguments?: string }) {
    try {
      const flakeDir = process.env.PWD || ".";
      const action = args.action || "list";

      if (action === "list") {
        const out = execSync("just --list 2>&1 || nix run .#just -- --list 2>&1", {
          encoding: "utf-8",
          timeout: 60_000,
          cwd: flakeDir,
        });
        return `Available just recipes:\n\n${out}`;
      }

      let cmd = `just ${action}`;
      if (args.arguments) {
        cmd += ` ${args.arguments}`;
      }
      cmd += " 2>&1";

      const out = execSync(cmd, {
        encoding: "utf-8",
        timeout: 300_000,
        cwd: flakeDir,
        maxBuffer: 10 * 1024 * 1024,
      });

      if (out.trim()) {
        return out;
      }

      return `✓ just ${action} completed successfully`;
    } catch (e: any) {
      const stderr = e.stderr || "";
      const stdout = e.stdout || "";
      const action = args.action || "list";
      return `just ${action} failed:\n${(stdout + stderr).trim()}`;
    }
  },
};
