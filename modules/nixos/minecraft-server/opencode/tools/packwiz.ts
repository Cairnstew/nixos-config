import { execSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

const modpacksRel = join("modules", "nixos", "minecraft-server", "modpacks");

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

function listModpacks(repo: string): string {
  try {
    return readdirSync(join(repo, modpacksRel)).filter((n) => !n.startsWith(".")).join(", ");
  } catch {
    return "(none yet)";
  }
}

export default {
  description:
    "Run the packwiz CLI inside a packwiz modpack in this repo (modules/nixos/minecraft-server/modpacks/<name>/). Commands: init, modrinth add <mod>, curseforge add --addon-id <id>, url add <url>, remove <file>.pw.toml, update --all, refresh, list.",
  args: {
    modpack: {
      type: "string",
      description: "Name of the modpack directory (e.g. 'testModpack').",
    },
    command: {
      type: "string",
      description: "packwiz subcommand + args, e.g. 'modrinth add sodium' or 'refresh'.",
    },
  },
  async execute(args: { modpack?: string; command?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, modpacksRel, args.modpack || "");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz: no such modpack '${args.modpack}'. Existing modpacks: ${listModpacks(repo)}.`;
    }
    if (!args.command) {
      return "packwiz: provide a command, e.g. 'modrinth add sodium', 'refresh', 'list', 'update --all', 'remove <file>.pw.toml'.";
    }
    try {
      const out = execSync(`nix run ${repo}#packwiz -- ${args.command} 2>&1`, {
        encoding: "utf-8",
        cwd: modpackDir,
        timeout: 900_000,
        maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim() || `✓ packwiz ${args.command} completed`;
    } catch (e: any) {
      return `packwiz ${args.command} failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
