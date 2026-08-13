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
    "Add a local custom datapack to a packwiz modpack via the Paxi loader folder (config/paxi/datapacks/). Copies a local .zip or directory in, validates its pack.mcmeta pack_format matches the pack's Minecraft version (1.21.1 = 48), and refreshes the index. Use for goal #2: patches / recipe & loot tweaks. Server-side datapacks work; resource packs are client-only.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    source: { type: "string", description: "Absolute path to the local datapack .zip or directory." },
    name: { type: "string", description: "Optional target name (defaults to the source basename)." },
  },
  async execute(args: { modpack?: string; source?: string; name?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.source || !existsSync(modpackDir)) {
      return `packwiz-datapack-add: need a valid modpack and source.`;
    }
    const cmd = `python3 ${script} ${modpackDir} datapack-add ${args.source}${args.name ? ` --name ${args.name}` : ""}`;
    try {
      const out = execSync(cmd + " 2>&1", { encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 20 * 1024 * 1024 });
      return out.trim();
    } catch (e: any) {
      return `packwiz-datapack-add failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
