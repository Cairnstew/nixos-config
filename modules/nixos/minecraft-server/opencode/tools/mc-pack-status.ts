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
    "Inspect and verify a packwiz modpack in this repo: mod count, index.toml sync, checksums.json coverage, CurseForge-mode mods (no download url — they break the Nix build), and duplicate jar filenames. Use before deploying a pack to a server.",
  args: {
    modpack: {
      type: "string",
      description: "Name of the modpack directory (e.g. 'testModpack').",
    },
  },
  async execute(args: { modpack?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack-status.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `mc-pack-status: no such modpack '${args.modpack}'.`;
    }
    try {
      const out = execSync(`python3 ${script} ${modpackDir} 2>&1`, {
        encoding: "utf-8",
        cwd: modpackDir,
        timeout: 60_000,
      });
      return out.trim();
    } catch (e: any) {
      const stdout = e.stdout || "";
      return `mc-pack-status: ${stdout.trim()}`;
    }
  },
};
