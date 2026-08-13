import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

export default {
  description:
    "Create or overwrite a default mod config file in a packwiz modpack's config/ dir and refresh the pack index. Use for goal #1: shipping sensible player defaults. Optionally mark it preserve so players' existing copies are never overwritten.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    relPath: { type: "string", description: "Path under config/, e.g. 'jei/jei.toml' or 'minecraft/options.txt'." },
    content: { type: "string", description: "File content to write. Omit to use sourceFile instead." },
    sourceFile: { type: "string", description: "Absolute path to a file to copy into the pack (alternative to content)." },
    preserve: { type: "string", description: "'true' to mark the index entry preserve (players keep their edits)." },
  },
  async execute(args: { modpack?: string; relPath?: string; content?: string; sourceFile?: string; preserve?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.relPath || !existsSync(modpackDir)) {
      return `packwiz-config-add: need a valid modpack and relPath.`;
    }
    const cmd: string[] = ["python3", script, modpackDir, "config-add", args.relPath];
    if (args.content != null) cmd.push("--content", args.content);
    if (args.sourceFile) cmd.push("--from", args.sourceFile);
    if (args.preserve === "true") cmd.push("--preserve");
    try {
      const out = execSync(cmd.join(" ") + " 2>&1", { encoding: "utf-8", cwd: modpackDir, timeout: 900_000, maxBuffer: 20 * 1024 * 1024 });
      return out.trim();
    } catch (e: any) {
      return `packwiz-config-add failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
