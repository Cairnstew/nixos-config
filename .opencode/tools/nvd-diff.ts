import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";

function nvd(args: string[], worktree: string): string {
  const cmd = `nix run nixpkgs#nvd -- ${args.map((a) => JSON.stringify(a)).join(" ")}`;
  try {
    const out = execSync(cmd, {
      cwd: worktree,
      encoding: "utf-8",
      timeout: 60_000,
      shell: "bash",
    });
    return out.trim();
  } catch (e: any) {
    return e.stderr || e.stdout || String(e);
  }
}

function findGeneration(num: number): string | null {
  const path = `/nix/var/nix/profiles/system-${num}-link`;
  try {
    execSync(`test -L "${path}"`, { encoding: "utf-8", timeout: 5_000 });
    return path;
  } catch {
    return null;
  }
}

function listGenerations(): { num: number; path: string }[] {
  try {
    const out = execSync(
      `ls -1 /nix/var/nix/profiles/system-*-link 2>/dev/null | sort -t- -k2 -n`,
      { encoding: "utf-8", timeout: 10_000 }
    );
    return out
      .trim()
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const m = line.match(/system-(\d+)-link/);
        return m ? { num: parseInt(m[1]), path: line } : null;
      })
      .filter(Boolean) as { num: number; path: string }[];
  } catch {
    return [];
  }
}

export default tool({
  description:
    "Diff two NixOS system generations or store paths to see what packages changed (added, removed, upgraded, downgraded). Uses nvd for clear, colorized output. Essential for understanding what a rebuild actually changed.",

  args: {
    from: tool.schema
      .string()
      .optional()
      .describe(
        "Source store path or generation number (e.g. '/run/current-system', '612', '/nix/store/...'). Defaults to the second-latest generation."
      ),
    to: tool.schema
      .string()
      .optional()
      .describe(
        "Target store path or generation number (e.g. '/run/current-system', '613', '/nix/store/...'). Defaults to the latest generation (current system)."
      ),
    mode: tool.schema
      .string()
      .optional()
      .default("diff")
      .describe(
        "Operation: 'diff' (compare two store paths), 'list' (list packages in a store path), 'history' (show generation history of a profile)."
      ),
    path: tool.schema
      .string()
      .optional()
      .describe("Store path or profile path for 'list' or 'history' mode. Defaults to /run/current-system."),
  },

  async execute(args, context) {
    const { from, to, mode, path } = args;
    const worktree = context.worktree || context.directory;

    if (mode === "list") {
      const target = path || "/run/current-system";
      return nvd(["list", target], worktree);
    }

    if (mode === "history") {
      const target = path || "/run/current-system";
      return nvd(["history", target], worktree);
    }

    const generations = listGenerations();
    if (generations.length < 2 && !from && !to) {
      return "Need at least 2 NixOS generations to diff, or provide explicit store paths via --from and --to.";
    }

    const resolvePath = (spec: string | undefined): string => {
      if (!spec) return "";
      const num = parseInt(spec);
      if (!isNaN(num) && String(num) === spec) {
        const p = findGeneration(num);
        if (p) return p;
        return `/nix/var/nix/profiles/system-${num}-link`;
      }
      return spec;
    };

    const fromPath = resolvePath(from) || (generations.length >= 2 ? generations[generations.length - 2].path : generations[0].path);
    const toPath = resolvePath(to) || generations[generations.length - 1].path;

    const result = nvd(["diff", fromPath, toPath], worktree);

    const fromGen = generations.find((g) => g.path === fromPath);
    const toGen = generations.find((g) => g.path === toPath);

    const header: string[] = [
      `Comparing:`,
      `  ${fromGen ? `Generation ${fromGen.num}` : fromPath}`,
      `  → ${toGen ? `Generation ${toGen.num}` : toPath}`,
      "",
    ];

    if (result.includes("No version or selection state changes")) {
      header.push("No package changes between these generations.");
      return header.join("\n");
    }

    return header.join("\n") + result;
  },
});
