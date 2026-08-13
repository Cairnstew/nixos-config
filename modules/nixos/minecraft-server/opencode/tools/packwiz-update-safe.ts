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
    "Safely update all mods in a packwiz modpack: `packwiz update --all` (pinned mods auto-skip) → regenerate checksums.json → verify with mc-pack-status → stage the pack. One-shot, verified update pipeline. Aborts on any failure before checksums change.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
  },
  async execute(args: { modpack?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const statusPy = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack-status.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-update-safe: no such modpack '${args.modpack}'.`;
    }
    const steps: string[] = [];
    try {
      steps.push("1/4 update --all");
      execSync(`nix run ${repo}#packwiz -- update --all 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 1800_000, maxBuffer: 20 * 1024 * 1024,
      });
      steps.push("2/4 regenerating checksums.json");
      execSync(`nix run ${repo}#packwiz-checksums-${args.modpack} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 3600_000, maxBuffer: 20 * 1024 * 1024,
      });
      steps.push("3/4 verifying pack");
      const status = execSync(`python3 ${statusPy} ${modpackDir} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 60_000,
      });
      if (!status.includes("READY for Nix build")) {
        return `packwiz-update-safe: pack NOT ready after update:\n${status.trim()}`;
      }
      steps.push("4/4 staging");
      execSync(`git add modules/nixos/minecraft-server/modpacks/${args.modpack} 2>&1`, {
        encoding: "utf-8", cwd: repo, timeout: 60_000,
      });
      return `✓ Update complete (${steps.join(" → ")}).\n\n${status.trim()}\n\nCommit the staged pack files when ready.`;
    } catch (e: any) {
      return `packwiz-update-safe failed during ${steps.join(" → ") || "setup"}:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
