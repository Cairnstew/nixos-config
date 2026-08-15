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
    "Regenerate checksums.json for a packwiz modpack in this repo. Downloads every mod jar and records its sha256 so the Nix server can build them. Run after adding/updating/removing mods, then commit checksums.json.",
  args: {
    modpack: {
      type: "string",
      description: "Name of the modpack directory (e.g. 'DragonTech').",
    },
  },
  async execute(args: { modpack?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-checksums: no such modpack '${args.modpack}'.`;
    }
    try {
      execSync(`nix run ${repo}#packwiz-checksums-${args.modpack} 2>&1`, {
        encoding: "utf-8",
        cwd: modpackDir,
        timeout: 3600_000,
        maxBuffer: 20 * 1024 * 1024,
      });
      return `✓ Regenerated checksums.json for ${args.modpack}. Commit it (git add) and rebuild the server.`;
    } catch (e: any) {
      return `packwiz-checksums failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
