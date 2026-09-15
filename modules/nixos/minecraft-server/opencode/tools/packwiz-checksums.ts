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
// Mirrors the RUN LOG pattern in the other packwiz tools: a `note` argument
// appends a RUN LOG entry to this tool's source AND its paired skill doc. The
// tool ALSO self-improves automatically: if it detects untracked mods (the
// "nix run only sees git-tracked files" trap) it blocks with instructions and
// logs the lesson to the skill's RUN LOG the first time it happens.
const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-checksums.ts");
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill.md");

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
  return `packwiz-checksums: appended RUN LOG entry to ${out.join(" and ")}`;
}

// Untracked .pw.toml files under <pack>/mods/. The checksum app runs via
// `nix run`, whose flake context only sees GIT-TRACKED files, so any untracked
// mod is silently omitted (checksum count stays one short of the on-disk count)
// and the mismatch only surfaces later via mc-pack-status.
function untrackedMods(repo: string, modpack: string): string[] {
  const rel = join("modules", "nixos", "minecraft-server", "modpacks", modpack, "mods");
  try {
    const out = execSync(`git -C ${repo} status --porcelain -- ${rel}`, { encoding: "utf-8" });
    return out
      .split("\n")
      .filter((l) => l.startsWith("??"))
      .map((l) => l.replace(/^\?\?\s+/, "").trim())
      .filter(Boolean);
  } catch {
    return [];
  }
}

// Log the untracked-mods lesson to the skill RUN LOG ONCE (dedupe key: the
// existing gotcha paragraph in skill.md). Returns an extra note for the reply.
function autoLogUntrackedTrap(repo: string, modpack: string, files: string[]): string {
  const skill = join(repo, SKILL_REL);
  if (!existsSync(skill)) return "";
  const lesson = `packwiz-checksums (auto): blocked ${modpack} — ${files.length} untracked mod file(s) (${files.join(", ")}). nix run only sees git-tracked files, so checksums would silently omit them; git add the mods first, then re-run.`;
  try {
    const existing = readFileSync(skill, "utf-8");
    // Already documented (either the gotcha block or a previous auto-entry) → don't spam.
    if (existing.includes("stays one short")) return "";
    const header = existing.includes("\n## RUN LOG") ? "" : "\n## RUN LOG\n";
    const date = new Date().toISOString().slice(0, 10);
    appendFileSync(skill, `${header}\n### ${date}\n${lesson}\n`);
    return "\n(Untracked-mods lesson appended to the skill RUN LOG.)";
  } catch {
    return "";
  }
}

export default {
  description:
    "Regenerate checksums.json for a packwiz modpack in this repo. Downloads every mod jar and records its sha256 so the Nix server can build them. Run after adding/updating/removing mods, then commit checksums.json. Blocks (and self-documents) if you forgot to git add newly-added mods first.",
  args: {
    modpack: {
      type: "string",
      description: "Name of the modpack directory (e.g. 'AllTheTech').",
    },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill.md)." },
  },
  async execute(args: { modpack?: string; note?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-checksums: no such modpack '${args.modpack}'.`;
    }
    const untracked = untrackedMods(repo, args.modpack);
    if (untracked.length > 0) {
      const extra = autoLogUntrackedTrap(repo, args.modpack, untracked);
      return `✗ packwiz-checksums blocked: ${untracked.length} untracked mod file(s) in ${args.modpack}/mods:\n  ${untracked.join("\n  ")}\nThe checksum app runs via \`nix run\`, which only sees git-tracked files — running now would silently omit those mods (checksum count stays one short of the on-disk count).\nRun \`git add modules/nixos/minecraft-server/modpacks/${args.modpack}\` FIRST, then re-run this tool.${extra}`;
    }
    try {
      execSync(`nix run ${repo}#packwiz-checksums-${args.modpack} 2>&1`, {
        encoding: "utf-8",
        cwd: modpackDir,
        timeout: 3600_000,
        maxBuffer: 20 * 1024 * 1024,
      });
      const logNote = args.note ? `\n(${appendRunLog(args.note)})` : "";
      return `✓ Regenerated checksums.json for ${args.modpack}. Commit it with \`git add modules/nixos/minecraft-server/modpacks/${args.modpack}/checksums.json\` and rebuild the server.${logNote}`;
    } catch (e: any) {
      return `packwiz-checksums failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-09-05
// Lesson: RarityCore (1211.14.6) added for 1.21.1 NeoForge. Known conflict with ImmediatelyFast: hud_batching=true causes nibbled hotbar item backgrounds (3/4 size) — RarityCore docs say disable ImmediatelyFast HUD batching to fix. Fix: ship config/immediatelyfast.json with hud_batching=false in the pack.
// ### 2026-09-05
// Lesson: LootJS (fJFETWDN, 3.7.0 neoforge 1.21.1) is required for regex injection into datapack/mod-defined loot tables — plain KubeJS only rewrites vanilla-held tables. Also: smallships items are wood-variant real ids (smallships:oak_war_galley), so logical ids in ITEM_TIERS.json must be mapped to a representative wood variant when referenced in KubeJS/LootJS addLoot().
// ### 2026-09-05
// Lesson: note= short-circuited regeneration — execute() returned appendRunLog() when args.note was set, silently SKIPPING the checksum regen (returned "appended RUN LOG", checksums.json stayed stale at 329 while mods dir had 330). Fix: note now appends only AFTER a successful nix-run regen (logNote appended to the success message); passing note always runs the checksums.
// ### 2026-09-07
// Added Apothic Attributes (DGaH8Rh0, 1.21.1-2.10.1) and its required dependency Placebo (tCkE8p2N, 1.21.1-9.9.2) to AllTheTech.
