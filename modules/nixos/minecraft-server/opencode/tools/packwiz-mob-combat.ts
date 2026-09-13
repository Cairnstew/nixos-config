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
const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-mob-combat.ts");
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-combat.md");

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
  return `packwiz-mob-combat: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Consolidate the raw combat-relevant facts for every entity in a pack: standard combat attributes (max_health, attack_damage, armor+armor_toughness, movement, knockback resistance, follow range), custom mod combat attributes (epicfight, etc. tagged by namespace, never folded into a score), spawn data (weight, biomes, dimensions, category), and a combat-data completeness classification (full/passive-only/custom-only/no-data). No scoring opinion — use packwiz-mob-tier for that. With entityInfo, look up one entity's full combat facts.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    entityInfo: { type: "string", description: "Look up a single entity's combat facts by ID." },
    mods: { type: "string", description: "Comma-separated mod slugs to restrict the jar scan to." },
    noDatapacks: { type: "boolean", description: "Skip scanning the pack's own datapacks." },
    noVanilla: { type: "boolean", description: "Omit the embedded vanilla baseline." },
    list: { type: "boolean", description: "Print entity ids, one per line." },
    json: { type: "boolean", description: "Return a machine-readable JSON document." },
    fullExport: { type: "string", description: "Write every entity's combat facts to a single JSON file." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry." },
  },
  async execute(args: { modpack?: string; entityInfo?: string; mods?: string; noDatapacks?: boolean; noVanilla?: boolean; list?: boolean; json?: boolean; fullExport?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mob-combat.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-mob-combat: need a valid modpack.`;
    }
    const argv = [];
    if (args.entityInfo) argv.push("--info", args.entityInfo);
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
      return `packwiz-mob-combat failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
