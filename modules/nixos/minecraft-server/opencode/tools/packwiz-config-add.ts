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
// appends a RUN LOG entry to this tool's source AND its paired skill doc.
const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-config-add.ts");
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-config-set.md");

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
  return `packwiz-config-add: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Create or overwrite a default mod config file in a packwiz modpack's config/ dir and refresh the pack index. Use for goal #1: shipping sensible player defaults. Optionally mark it preserve so players' existing copies are never overwritten.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    relPath: { type: "string", description: "Path under config/, e.g. 'jei/jei.toml' or 'minecraft/options.txt'." },
    content: { type: "string", description: "File content to write. Omit to use sourceFile instead." },
    sourceFile: { type: "string", description: "Absolute path to a file to copy into the pack (alternative to content)." },
    preserve: { type: "string", description: "'true' to mark the index entry preserve (players keep their edits)." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-config-set.md)." },
  },
  async execute(args: { modpack?: string; relPath?: string; content?: string; sourceFile?: string; preserve?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.relPath || !existsSync(modpackDir)) {
      return `packwiz-config-add: need a valid modpack and relPath.`;
    }
    const cmd: string[] = ["python3", script, modpackDir, "config-add", args.relPath];
    if (args.content != null) cmd.push("--content", args.content);
    if (args.sourceFile) cmd.push("--from", args.sourceFile);
    if (args.preserve === "true") cmd.push("--preserve");
    const quoted = cmd.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(quoted + " 2>&1", { encoding: "utf-8", cwd: modpackDir, timeout: 900_000, maxBuffer: 20 * 1024 * 1024 });
      return out.trim();
    } catch (e: any) {
      return `packwiz-config-add failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
