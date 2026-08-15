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
    "Print a member (default META-INF/neoforge.mods.toml) from a mod's PINNED jar in a packwiz modpack — the exact bytes a build-time patch (patches/<mod>.py, registered in patches.nix) must match. Use to write or verify patches for jar metadata that config changes cannot control (e.g. a dependency versionRange that pins a nonexistent version).",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'DragonTech')." },
    mod: { type: "string", description: "Mod name, slug, or .pw.toml filename (e.g. 'dynamic-trees-still-life')." },
    member: { type: "string", description: "Jar member to print, e.g. 'META-INF/neoforge.mods.toml' (default)." },
  },
  async execute(args: { modpack?: string; mod?: string; member?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.mod || !existsSync(modpackDir)) {
      return `packwiz-jar-meta: need a valid modpack and mod.`;
    }
    const argv = ["jar-meta", args.mod];
    if (args.member) argv.push(args.member);
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-jar-meta failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
