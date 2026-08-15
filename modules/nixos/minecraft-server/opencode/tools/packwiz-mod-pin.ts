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
    "Pin or unpin a mod in a packwiz modpack. Pin = the mod is NEVER auto-updated (even `update <mod>` fails until unpinned). Use to freeze a version that a config override or datapack depends on.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'DragonTech')." },
    mod: { type: "string", description: "Mod name or .pw.toml filename to pin/unpin (list first to get exact names)." },
    action: { type: "string", description: "'pin', 'unpin', or 'status' (default pin)." },
  },
  async execute(args: { modpack?: string; mod?: string; action?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    if (!args.modpack || !args.mod || !existsSync(modpackDir)) {
      return `packwiz-mod-pin: need a valid modpack and mod name.`;
    }
    const action = args.action || "pin";
    try {
      if (action === "status") {
        // packwiz `list` doesn't visually mark pinned mods; the field lives in
        // each mods/*.pw.toml as `pinned = true`. Scan for it directly.
        const { readdirSync, readFileSync } = await import("node:fs");
        const { join } = await import("node:path");
        const modsDir = join(modpackDir, "mods");
        const pinned: string[] = [];
        for (const f of readdirSync(modsDir).filter((n) => n.endsWith(".pw.toml")).sort()) {
          const txt = readFileSync(join(modsDir, f), "utf-8");
          if (/^pin\s*=\s*true/m.test(txt)) {
            const m = txt.match(/^name\s*=\s*"([^"]+)"/m);
            pinned.push(m ? m[1] : f);
          }
        }
        return pinned.length ? `Pinned mods:\n${pinned.map((p) => `  - ${p}`).join("\n")}` : "No pinned mods.";
      }
      const out = execSync(`nix run ${repo}#packwiz -- ${action} ${args.mod} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 900_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim() || `✓ ${action === "pin" ? "Pinned" : "Unpinned"} ${args.mod}`;
    } catch (e: any) {
      return `packwiz-mod-pin ${action} ${args.mod} failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
