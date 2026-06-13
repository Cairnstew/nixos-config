import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";

function runTool(pkg: string, args: string[], worktree: string, timeout: number): string {
  const cmd = `nix run nixpkgs#${pkg} -- ${args.map((a) => JSON.stringify(a)).join(" ")}`;
  try {
    const out = execSync(cmd, {
      cwd: worktree,
      encoding: "utf-8",
      timeout,
      shell: "bash",
    });
    return out.trim();
  } catch (e: any) {
    return e.stderr?.trim() || e.stdout?.trim() || `Exit code ${e.status || 1}`;
  }
}

export default tool({
  description:
    "Lint Nix files for dead code and antipatterns. Runs statix (antipattern linter) and deadnix (dead code finder) together. Use before committing to catch unused variables, unnecessary rec, incorrect let-in patterns, and more.",

  args: {
    path: tool.schema
      .string()
      .optional()
      .describe(
        "File or directory to lint. Defaults to the whole repo. Use specific file paths for faster results (e.g. 'modules/nixos/tailscale.nix')."
      ),
    fix: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Apply statix auto-fixes to lint errors (destructive — modifies files)."),
    quiet: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Suppress deadnix report lines; only show summary counts."),
    checkers: tool.schema
      .string()
      .optional()
      .default("statix,deadnix")
      .describe("Comma-separated list of checkers to run: 'statix', 'deadnix', or 'statix,deadnix' (default)."),
  },

  async execute(args, context) {
    const { path: targetPath, fix, quiet, checkers } = args;
    const worktree = context.worktree || context.directory;
    const lintPath = targetPath || worktree;
    const enabled = (checkers || "statix,deadnix").split(",").map((s) => s.trim().toLowerCase());

    const lines: string[] = [];

    if (enabled.includes("statix")) {
      lines.push("── statix (antipattern linter) ──");
      lines.push("");
      try {
        const action = fix ? "fix" : "check";
        const result = runTool("statix", [action, lintPath], worktree, 120_000);
        lines.push(result || "No lint issues found.");
      } catch {
        lines.push("statix: error running linter");
      }
      lines.push("");
    }

    if (enabled.includes("deadnix")) {
      lines.push("── deadnix (dead code finder) ──");
      lines.push("");
      try {
        const deadnixArgs: string[] = [];
        if (quiet) deadnixArgs.push("-q");
        deadnixArgs.push("--hidden");
        deadnixArgs.push(lintPath);
        const result = runTool("deadnix", deadnixArgs, worktree, 120_000);
        lines.push(result || "No dead code found.");
      } catch {
        lines.push("deadnix: error running linter");
      }
      lines.push("");
    }

    lines.push(`Linted: ${lintPath}`);
    return lines.join("\n");
  },
});
