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
    "Diff the pack's config/<rel-path> override against the owning mod's stock default config (downloaded from checksums.json, unzipped from the jar). Use to review exactly what your shipped config changes vs the mod default before adding it.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'DragonTech')." },
    relPath: { type: "string", description: "Path under config/, e.g. 'jei/jei.toml'." },
  },
  async execute(args: { modpack?: string; relPath?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.relPath || !existsSync(modpackDir)) {
      return `packwiz-config-diff: need a valid modpack and relPath.`;
    }
    try {
      const out = execSync(`python3 ${script} ${modpackDir} config-diff ${args.relPath} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-config-diff failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
