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
    "Inventory the internal files shipped by a packwiz modpack (config/, kubejs/, scripts/, datapacks/, defaultconfigs/) and their index/preserve state. Use before editing configs or patches to see what's already shipped.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    all: { type: "string", description: "'true' to list every internal dir (config/ is the default)." },
  },
  async execute(args: { modpack?: string; all?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-config-list: no such modpack '${args.modpack}'.`;
    }
    try {
      const flag = args.all === "true" ? "--all" : "";
      const out = execSync(`python3 ${script} ${modpackDir} config-list ${flag} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 60_000,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-config-list failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
