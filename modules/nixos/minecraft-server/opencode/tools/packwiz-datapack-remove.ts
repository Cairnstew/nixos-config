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
    "Remove a custom datapack from a packwiz modpack's Paxi loader folder (config/paxi/datapacks/) and refresh the index.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    name: { type: "string", description: "Datapack name to remove (zip or directory)." },
  },
  async execute(args: { modpack?: string; name?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.name || !existsSync(modpackDir)) {
      return `packwiz-datapack-remove: need a valid modpack and name.`;
    }
    try {
      const out = execSync(`python3 ${script} ${modpackDir} datapack-remove ${args.name} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-datapack-remove failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
