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
const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-item-tier.ts");
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-item-tier.md");

function appendRunLog(note: string): string {
  const repo = repoRoot();
  const src = join(repo, SOURCE_REL);
  const out: string[] = [];
  if (existsSync(src)) {
    const date = new Date().toISOString().slice(0, 10);
    try {
      const srcExisting = readFileSync(src, "utf-8");
      const srcHeader = srcExisting.includes("\n// ## RUN LOG") ? "" : "\n// ## RUN LOG\n";
      appendFileSync(src, `${srcHeader}// ### ${date}\n// ${note.replace(/\n/g, "\n// ")}\n`);
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
  return `packwiz-item-tier: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Compute deterministic 0-7 rarity tiers for every item in a pack. Uses item-acquisition.py data to score items based on acquisition difficulty. Tier scale: 0=world-generated blocks, 1=common resources, 2=uncommon, 3=rare, 4=crafted, 5=advanced crafted, 6=endgame, 7=ultra-rare/admin. Multi-path items resolve to easiest path. Supports curated overrides via tier-overrides.toml. With itemInfo, look up a single item's tier with full factor breakdown.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    itemInfo: { type: "string", description: "Look up a single item by ID and return its tier with full breakdown." },
    mods: { type: "string", description: "Comma-separated mod slugs to restrict the jar scan to." },
    noDatapacks: { type: "boolean", description: "Skip scanning the pack's own datapacks." },
    noVanilla: { type: "boolean", description: "Omit the embedded vanilla baseline." },
    list: { type: "boolean", description: "Print item_id=tier pairs, one per line." },
    json: { type: "boolean", description: "Return a machine-readable JSON document." },
    fullExport: { type: "string", description: "Write every item's tier record to a single JSON file." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry." },
  },
  async execute(args: { modpack?: string; itemInfo?: string; mods?: string; noDatapacks?: boolean; noVanilla?: boolean; list?: boolean; json?: boolean; fullExport?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "item-tier.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-item-tier: need a valid modpack.`;
    }
    const argv = [];
    if (args.itemInfo) argv.push("--info", args.itemInfo);
    if (args.mods) argv.push("--mods", args.mods);
    if (args.noDatapacks) argv.push("--no-datapacks");
    if (args.noVanilla) argv.push("--no-vanilla");
    if (args.list) argv.push("--list");
    if (args.json) argv.push("--json");
    if (args.fullExport !== undefined) {
      argv.push("--full-export");
      if (args.fullExport) argv.push(args.fullExport);
    }
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 600_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-item-tier failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-09-07
// Created as the opencode tool wrapper for item-tier.py. Delegates to the
// standalone tool engine (same CLI, same flags). Args: modpack, itemInfo, mods,
// noDatapacks, noVanilla, list, json, fullExport, note.
