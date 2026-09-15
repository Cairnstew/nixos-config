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
const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-mob-tier.ts");
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-tier.md");

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
  return `packwiz-mob-tier: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Compute deterministic 0-7 combat-difficulty tiers for every mob in a pack, from mob-combat facts. Three scores are reported separately: combat_tier (0-7 from stats alone — health, attack damage, armor as effective DR, movement/knockback as small multipliers), context_score (0-7 from dimension difficulty + spawn rarity), and combined_tier (combat × context, the headline). Passive mobs are never scored (n/a, not a fake 0); bosses carry a stats-only note (no fake boss bonus); custom-only/no-data mobs get tier null with an explicit reason and confidence partial. With mobInfo, look up one mob's tier with full factor breakdown.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    mobInfo: { type: "string", description: "Look up a single mob's tier by ID with full factor breakdown." },
    mods: { type: "string", description: "Comma-separated mod slugs to restrict the jar scan to." },
    noDatapacks: { type: "boolean", description: "Skip scanning the pack's own datapacks." },
    noVanilla: { type: "boolean", description: "Omit the embedded vanilla baseline." },
    list: { type: "boolean", description: "Print entity_id=tier pairs, one per line." },
    json: { type: "boolean", description: "Return a machine-readable JSON document." },
    fullExport: { type: "string", description: "Write every mob's tier record to a single JSON file." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry." },
  },
  async execute(args: { modpack?: string; mobInfo?: string; mods?: string; noDatapacks?: boolean; noVanilla?: boolean; list?: boolean; json?: boolean; fullExport?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mob-tier.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-mob-tier: need a valid modpack.`;
    }
    const argv = [];
    if (args.mobInfo) argv.push("--info", args.mobInfo);
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
        encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-mob-tier failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
