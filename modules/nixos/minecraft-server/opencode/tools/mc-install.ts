import { execSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, appendFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// ── Shared helpers (kept in-file: opencode copies each tool to
// ~/.config/opencode/tools/ individually, so sibling imports don't resolve) ──

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

function dataDirCandidates(): string[] {
  const home = homedir();
  return [
    process.env.PRISMLAUNCHER_DIR || "",
    "/mnt/media/Modding/PrismLauncher",
    "/mnt/data/prismlauncher",
    join(home, ".local", "share", "PrismLauncher"),
    join(home, ".var", "app", "org.prismlauncher.PrismLauncher", "data", "PrismLauncher"),
  ].filter(Boolean);
}

function findDataDir(): string | null {
  for (const dir of dataDirCandidates()) {
    if (existsSync(join(dir, "instances"))) return dir;
  }
  return null;
}

function listInstances(dataDir: string): string[] {
  const dir = join(dataDir, "instances");
  return existsSync(dir)
    ? readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name)
    : [];
}

function findInstanceDir(dataDir: string, modpack: string): string | null {
  const dirs = listInstances(dataDir);
  if (dirs.length === 0) return null;
  const exact = dirs.find((d) => d === modpack);
  if (exact) return join(dataDir, "instances", exact);
  const lower = dirs.find((d) => d.toLowerCase() === modpack.toLowerCase());
  if (lower) return join(dataDir, "instances", lower);
  for (const d of dirs) {
    const cfg = join(dataDir, "instances", d, "instance.cfg");
    if (!existsSync(cfg)) continue;
    const m = readFileSync(cfg, "utf-8").match(/^name=(.*)$/m);
    if (m && m[1] === modpack) return join(dataDir, "instances", d);
  }
  return null;
}

// ── Self-improvement ─────────────────────────────────────────────────────────
// Same protocol as mc-run / mc-prism-log: the source of truth is the repo file
//   modules/nixos/minecraft-server/opencode/tools/mc-install.ts
// A `note` argument appends a RUN LOG entry programmatically; the agent should
// otherwise edit the repo file directly when it finds a bug or improvement.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "mc-install.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill.md");

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
  return `mc-install: appended RUN LOG entry to ${out.join(" and ")}`;
}

// ── Build via the flake part ─────────────────────────────────────────────────
// The authoritative builder is the flake app:
//   nix run .#modpack-build-<name> [dataDir] [server]
// which builds the pack's client content (modules/flake-parts/packwiz.nix
// mkBuildApp) and installs it via the shared instance-sync script
// (packwiz-instance-sync.py). This tool first BUILDS the content to get the
// store path, COMPARES it against what's currently installed in the Prism
// instance, and only calls the app when an update is needed (or force=true).

function buildContent(repo: string, modpack: string): { out: string; meta: any } | string {
  try {
    const out = execSync(`nix build ${repo}#minecraft-modpack-${modpack} --no-link --print-out-paths 2>/dev/null`, {
      encoding: "utf-8",
      timeout: 900_000,
    }).trim().split("\n").pop();
    if (!out || !existsSync(join(out, "meta.json"))) {
      return `mc-install: built ${modpack} but no meta.json at ${join(out, "meta.json")}`;
    }
    const meta = JSON.parse(readFileSync(join(out, "meta.json"), "utf-8"));
    return { out, meta };
  } catch (e: any) {
    return `mc-install: nix build ${repo}#minecraft-modpack-${modpack} failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
  }
}

// Compare built content against the installed instance using the SAME rsync
// semantics as packwiz-instance-sync.py (mods dir is pack-owned and
// --delete'd; config/kubejs/scripts/datapacks/defaultconfigs are only seeded
// when absent). Returns a list of human-readable differences.
function compareContent(out: string, instanceDir: string): string[] {
  const diffs: string[] = [];
  const builtMc = join(out, ".minecraft");
  const instMc = join(instanceDir, ".minecraft");

  // mods: pack-owned, full mirror. Dry-run rsync with --delete reproduces
  // exactly what instance-sync does; any output line = a difference.
  const builtMods = join(builtMc, "mods");
  const instMods = join(instMc, "mods");
  if (existsSync(builtMods)) {
    if (!existsSync(instMods)) {
      diffs.push(`mods/ directory missing in instance (${builtMods} → ${instMods})`);
    } else {
      const r = execSync(
        `rsync -a -L --delete --dry-run --out-format=%n '${builtMods}/' '${instMods}/' 2>/dev/null`,
        { encoding: "utf-8" }
      );
      const lines = r.split("\n").map((l) => l.trim()).filter((l) => l.length > 0 && !l.endsWith("/"));
      for (const l of lines) {
        const prefix = l.startsWith("deleting ") ? "mods/ (removed)" : "mods/";
        diffs.push(`${prefix}${l.replace(/^deleting /, "")}`);
      }
    }
  }

  // internal dirs: seeded only when absent (matches --ignore-existing).
  for (const d of ["config", "kubejs", "scripts", "datapacks", "defaultconfigs"]) {
    const built = join(builtMc, d);
    const inst = join(instMc, d);
    if (existsSync(built) && !existsSync(inst)) {
      diffs.push(`${d}/ present in pack but missing from instance`);
    }
  }

  // game-root files (e.g. shipped default options.txt): seeded only when absent.
  for (const f of ["options.txt"]) {
    const built = join(builtMc, f);
    const inst = join(instMc, f);
    if (existsSync(built) && !existsSync(inst)) {
      diffs.push(`${f} present in pack but missing from instance`);
    }
  }

  return diffs;
}

// Compare instance.cfg loader/MC version against the built meta.json.
function versionDiffs(instanceDir: string, meta: any): string[] {
  const diffs: string[] = [];
  const cfg = join(instanceDir, "instance.cfg");
  if (!existsSync(cfg)) return [`instance.cfg missing in ${instanceDir}`];
  const text = readFileSync(cfg, "utf-8");
  const mcMatch = text.match(/^MinecraftVersion=(.*)$/m);
  const compMatch = text.match(/^Components=(.*)$/m);
  if (mcMatch && mcMatch[1] !== meta.mc) {
    diffs.push(`Minecraft ${mcMatch[1]} → ${meta.mc}`);
  }
  const wantComp = `${meta.loaderUid}:${meta.loaderVersion}`;
  if (compMatch && compMatch[1] !== wantComp) {
    diffs.push(`loader ${compMatch[1]} → ${wantComp}`);
  }
  return diffs;
}

export default {
  description:
    "Build a packwiz modpack's client content via the flake part (.#minecraft-modpack-<name> / modpack-build-<name>) and install it into the Prism Launcher instance, but only when it has actually changed. First builds the content to a store path, compares it against what's currently installed in the Prism instance (mods dir mirror with --delete, internal dirs seeded-once, and instance.cfg MC/loader versions) using the same methodology as packwiz-instance-sync.py, then calls `nix run .#modpack-build-<name>` only if differences exist (or force=true).",
  args: {
    modpack: {
      type: "string",
      description: "Modpack name (e.g. 'AllTheTech'). Must have a flake app/packages.minecraft-modpack-<name>.",
    },
    dataDir: {
      type: "string",
      description: "Prism Launcher data dir override (default: auto-detect from known locations).",
    },
    server: {
      type: "string",
      description: "Server address (host:port) written into instance.cfg [JoinServerOnLaunch], e.g. 'server.tail685690.ts.net:25565'.",
    },
    force: {
      type: "boolean",
      description: "Reinstall even if the built content matches the installed instance.",
    },
    dryRun: {
      type: "boolean",
      description: "Only compare and report differences; do not install.",
    },
    note: {
      type: "string",
      description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill.md).",
    },
  },
  async execute(args: { modpack?: string; dataDir?: string; server?: string; force?: boolean; dryRun?: boolean; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    if (!args.modpack) {
      return "mc-install: provide a modpack name (e.g. 'AllTheTech').";
    }
    const repo = repoRoot();
    const built = buildContent(repo, args.modpack);
    if (typeof built === "string") return built;
    const { out, meta } = built;

    const dataDir = args.dataDir || findDataDir() || "";
    const instanceDir = dataDir ? findInstanceDir(dataDir, args.modpack) : null;
    if (!dataDir || !instanceDir) {
      return `mc-install: built '${args.modpack}' → ${out}, but no Prism instance found (dataDir ${dataDir || "not found"}). Run 'nix run .#modpack-build-${args.modpack}' manually with an explicit data dir.`;
    }

    const diffs = [...compareContent(out, instanceDir), ...versionDiffs(instanceDir, meta)];

    if (diffs.length === 0 && !args.force) {
      return `mc-install: '${args.modpack}' is up to date — built ${out} matches the instance at ${instanceDir} (no mods/version changes). Use force=true to reinstall anyway.`;
    }

    const diffText = diffs.length ? diffs.map((d) => `  - ${d}`).join("\n") : "  (no content differences)";
    if (args.dryRun) {
      return `mc-install: '${args.modpack}' WOULD be updated (built ${out}):\n${diffText}\nInstance: ${instanceDir}`;
    }

    // Run the authoritative flake app: build + install via instance-sync.py.
    try {
      const appArgs = [dataDir];
      if (args.server) appArgs.push(args.server);
      const out2 = execSync(`nix run ${repo}#modpack-build-${args.modpack} -- ${appArgs.map((a) => `'${a}'`).join(" ")} 2>&1`, {
        encoding: "utf-8",
        timeout: 900_000,
        maxBuffer: 20 * 1024 * 1024,
      });
      return `mc-install: updated '${args.modpack}' (was out of date):\n${diffText}\n\n${out2.trim()}`;
    } catch (e: any) {
      return `mc-install: install failed for '${args.modpack}':\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-08-14
// 2026-08-14 — config defaults seeded with --ignore-existing
// Lesson: shipping a changed mod default config (roadweaver roadweaver.json whitelist) into an existing Prism instance was skipped: instance-sync seeds config/ with --ignore-existing, and compareContent only flags internal dirs as present/absent, so mc-install reported "up to date" despite the stale file. Fix: documented in mc-mod-config-set skill gotchas — delete the stale instance config file first, then force=true.

// ## RUN LOG
// ### 2026-08-14
// 2026-08-14 — re-seed roadweaver.json (water-crossing road fix)
// Lesson: user reported roads paving through ocean/water (RoadWeaver issue #68 — water in land-tagged biomes treated as land; plus whitelist forced roads to ocean structures structory:boat + dragonsurvival:*_sea, and predictRadiusChunks 1024 connected structures 16km apart). Seeding needed --ignore-existing workaround: remove the instance copy first.
// Fix: bumped waterDepthWeight 80->200, nearWaterCost 80->160, biomeWeight 2->4; blacklisted structory:boat + 3 dragonsurvival sea structures; predictRadiusChunks 1024->256.
