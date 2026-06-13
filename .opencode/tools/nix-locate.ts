import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function indexExists(): boolean {
  return existsSync(join(homedir(), ".cache", "nix-index", "files"));
}

function runLocate(args: string[], worktree: string): string {
  const cmd = `nix shell nixpkgs#nix-index -c nix-locate ${args.map((a) => JSON.stringify(a)).join(" ")}`;
  try {
    const out = execSync(cmd, {
      cwd: worktree,
      encoding: "utf-8",
      timeout: 60_000,
      shell: "bash",
    });
    return out.trim();
  } catch (e: any) {
    return e.stderr?.trim() || e.stdout?.trim() || `Exit code ${e.status || 1}`;
  }
}

export default tool({
  description:
    "Quickly find which Nix package provides a specific file or binary. Uses nix-index's pre-built cache for near-instant results. Much faster than 'nix search' for finding 'which package has this binary?' questions.",

  args: {
    pattern: tool.schema
      .string()
      .describe(
        "File or binary name to search for (e.g. 'fzf', 'bin/helm', 'libsqlite3.so'). Supports partial matches by default."
      ),
    exact: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Only match exact filename (uses --whole-name flag)."),
    executable: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Only search for executable files (--type x)."),
    update: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Update the nix-index cache before searching (requires network)."),
  },

  async execute(args, context) {
    const { pattern, exact, executable, update } = args;
    const worktree = context.worktree || context.directory;

    if (!pattern) {
      return "Provide a filename or pattern to search for (e.g. 'fzf', 'bin/helm').";
    }

    if (update) {
      return [
        "Triggering nix-index cache update...",
        `Run \`nix run nixpkgs#nix-index\` in a terminal to update the index.`,
        "This downloads a large database (~100MB+) and may take a few minutes.",
        "",
        "Once updated, run this tool again with your pattern.",
      ].join("\n");
    }

    if (!indexExists()) {
      return [
        "nix-index cache not found at ~/.cache/nix-index/files.",
        "",
        "Generate it first by running in your terminal:",
        "  nix run nixpkgs#nix-index",
        "",
        "This downloads the pre-built package index (~100MB, may take a few minutes).",
        "After it completes, try this search again.",
        "",
        "Alternatively, use the nixos_nix tool with action='search' to search nixpkgs.",
      ].join("\n");
    }

    const locateArgs: string[] = [];
    if (exact) locateArgs.push("--whole-name");
    if (executable) locateArgs.push("--type", "x");
    locateArgs.push(pattern);

    const result = runLocate(locateArgs, worktree);

    if (!result || result.includes("no results found")) {
      return `No packages found matching "${pattern}". Try a broader pattern or use 'nix search' instead.`;
    }

    const lines = result.split("\n");
    const limited = lines.slice(0, 50);
    const summary = [`Found ${lines.length} result(s) for "${pattern}":`, ""];

    return summary.concat(limited).join("\n") + (lines.length > 50 ? `\n\n... and ${lines.length - 50} more results (refine with a more specific pattern).` : "");
  },
});
