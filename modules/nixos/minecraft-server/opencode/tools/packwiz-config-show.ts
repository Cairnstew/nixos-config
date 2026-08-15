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
    "Review/get the config a specific mod in a packwiz modpack ships: resolve the mod to its pinned jar (from checksums.json — the exact jar players get), list the config/ files it bundles with sizes and whether the pack overrides each, and print the contents of a chosen file. Pairs with packwiz-config-diff to review pack overrides against the mod's stock defaults.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    mod: { type: "string", description: "Mod name, slug, or .pw.toml filename (e.g. 'jei', 'Just Enough Items', 'jei.pw.toml')." },
    path: { type: "string", description: "Optional config file inside the jar to print, e.g. 'config/jei/jei.toml' (omit to list all shipped configs)." },
    contents: { type: "string", description: "'true' to print the contents of every shipped config file (not just the listing)." },
  },
  async execute(args: { modpack?: string; mod?: string; path?: string; contents?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.mod || !existsSync(modpackDir)) {
      return `packwiz-config-show: need a valid modpack and mod.`;
    }
    const argv = ["config-show", args.mod];
    if (args.path) argv.push(args.path);
    if (args.contents === "true") argv.push("--contents");
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-config-show failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
