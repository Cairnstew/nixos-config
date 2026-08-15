import { execSync } from "node:child_process";
import { existsSync, appendFileSync, readFileSync } from "node:fs";
import { join } from "node:path";

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

// ── Self-improvement ─────────────────────────────────────────────────────────
// Mirrors the RUN LOG pattern in the mc-* launcher tools, scoped to this tool's
// source. The runtime copy (~/.config/opencode/tools/) is a read-only store
// symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/packwiz-structures.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-structures.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-structures.md");

function appendRunLog(note: string): string {
  const repo = repoRoot();
  const src = join(repo, SOURCE_REL);
  const out: string[] = [];
  if (existsSync(src)) {
    const date = new Date().toISOString().slice(0, 10);
    try {
      appendFileSync(src, `\n// ## RUN LOG\n// ### ${date}\n// ${note.replace(/\n/g, "\n// ")}\n`);
      out.push(`tool source ${src}`);
    } catch (e: any) {
      out.push(`tool source FAILED (${e.message})`);
    }
  }
  const skill = join(repo, SKILL_REL);
  if (existsSync(skill)) {
    try {
      const date = new Date().toISOString().slice(0, 10);
      const existing = readFileSync(skill, "utf-8");
      const header = existing.includes("\n## RUN LOG") ? "" : "\n## RUN LOG\n";
      appendFileSync(skill, `${header}\n### ${date}\n${note}\n`);
      out.push(`skill ${skill}`);
    } catch (e: any) {
      out.push(`skill FAILED (${e.message})`);
    }
  }
  return `packwiz-structures: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Review every worldgen structure + structure set a packwiz modpack will generate — from the pack's PINNED mod jars (checksums.json, exactly what players get) and its own datapacks (config/paxi/datapacks/ + any pack-level data/). Lists structures with their type and biome tag, structure sets with the structures they spawn, flags structures referenced-but-missing, and flags 'minecraft:'-namespace structures the pack/mods redefine (vanilla overrides). Full-pack scans cache downloaded jars by checksum so re-runs are instant.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    mods: { type: "string", description: "Comma-separated mod slugs to restrict the scan to (e.g. 'ae2,still-life'). Omit to scan the whole pack." },
    noDatapacks: { type: "boolean", description: "Skip scanning the pack's own datapacks (Paxi + data/)." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-structures.md)." },
  },
  async execute(args: { modpack?: string; mods?: string; noDatapacks?: boolean; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-structures: need a valid modpack.`;
    }
    const argv = ["structures"];
    if (args.mods) argv.push("--mods", args.mods);
    if (args.noDatapacks) argv.push("--no-datapacks");
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 600_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-structures failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-08-14
// 2026-08-14 — investigate ocean-crossing roads (user report)
// Lesson: RoadWeaver issue #68 — roads pave through water in modded/untagged water biomes; check which whitelisted structure mods spawn structures in/near ocean so roads get forced across water.
// Fix: none yet; scan to find ocean-spawning structures in the whitelist.

// ## RUN LOG
// ### 2026-08-14
// placeholder-scan
