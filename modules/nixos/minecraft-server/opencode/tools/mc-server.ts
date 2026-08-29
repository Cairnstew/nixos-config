import { execSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync, appendFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// ── Self-improvement ─────────────────────────────────────────────────────────
// Mirrors the researcher agent's SELF_IMPROVE + RUN LOG pattern, scoped to this
// tool's source. The runtime copy (~/.config/opencode/tools/) is a read-only
// store symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/mc-server.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "mc-server.ts");
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
  return `mc-server: appended RUN LOG entry to ${out.join(" and ")}`;
}

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

// Server definitions: modules/nixos/minecraft-server/servers/*.nix each define
// `my.services.minecraftServer.servers.<name>`. List them.
function listServers(repo: string): string[] {
  const dir = join(repo, "modules", "nixos", "minecraft-server", "servers");
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith(".nix") && f !== "default.nix")
    .map((f) => f.replace(/\.nix$/, ""));
}

// Find which server(s) a modpack is wired to: scan server nix files for
// `packwiz = ../modpacks/<pack>`.
function serversForPack(repo: string, modpack: string): string[] {
  const dir = join(repo, "modules", "nixos", "minecraft-server", "servers");
  if (!existsSync(dir)) return [];
  const hits: string[] = [];
  for (const f of readdirSync(dir)) {
    if (!f.endsWith(".nix") || f === "default.nix") continue;
    let text = "";
    try {
      text = readFileSync(join(dir, f), "utf-8");
    } catch {
      continue;
    }
    if (!text.includes(`modpacks/${modpack}`)) continue;
    const m = text.match(/servers\.([A-Za-z0-9_-]+)\s*=\s*{/);
    if (m) hits.push(m[1]);
  }
  return hits;
}

function findServerLogDir(): string | null {
  for (const dir of ["/mnt/data/minecraft", "/var/lib/minecraft", join(homedir(), ".minecraft-server")]) {
    if (existsSync(dir)) return dir;
  }
  return null;
}

function newestFile(dir: string): string | null {
  const files = existsSync(dir)
    ? readdirSync(dir).filter((f) => !f.endsWith(".gz")).map((f) => join(dir, f))
    : [];
  if (files.length === 0) return null;
  files.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  return files[0];
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function systemctl(args: string[]): { ok: boolean; out: string } {
  try {
    const out = execSync(`systemctl ${args.join(" ")} 2>&1`, { encoding: "utf-8", timeout: 30_000 });
    return { ok: true, out: out.trim() };
  } catch (e: any) {
    return { ok: false, out: ((e.stdout || "") + (e.stderr || "")).trim() };
  }
}

// The minecraft-server module exposes a dashboard management API on loopback
// (my.services.minecraftServer.api.*, default port 7799). When reachable it
// gives structured status (state, players, uptime) and start/stop/restart.
function apiBase(): string | null {
  for (const port of ["7799", "17801"]) {
    try {
      const out = execSync(`curl -s -m 3 http://127.0.0.1:${port}/status 2>/dev/null`, { encoding: "utf-8", timeout: 5_000 });
      if (out.trim().startsWith("[")) return `http://127.0.0.1:${port}`;
    } catch {
      /* try next */
    }
  }
  return null;
}

function apiStatus(api: string | null, server: string): { state: string; players?: string; uptime?: string } | null {
  if (!api) return null;
  try {
    const out = execSync(`curl -s -m 5 ${api}/status 2>/dev/null`, { encoding: "utf-8", timeout: 8_000 });
    const list = JSON.parse(out);
    const s = (Array.isArray(list) ? list : list.servers || []).find((x: any) => x.name === server);
    if (!s) return null;
    return {
      state: s.active ? "active" : s.state || "inactive",
      players: s.players != null ? `${s.players}` : undefined,
      uptime: s.uptime || undefined,
    };
  } catch {
    return null;
  }
}

function apiAction(api: string | null, server: string, action: string): string | null {
  if (!api) return null;
  try {
    const out = execSync(`curl -s -m 120 -X POST ${api}/${server}/${action} 2>/dev/null`, { encoding: "utf-8", timeout: 130_000 });
    return out.trim();
  } catch (e: any) {
    return ((e.stdout || "") + (e.stderr || "")).trim() || "request failed";
  }
}

// ── Status ───────────────────────────────────────────────────────────────────
function status(repo: string, server: string, api: string | null): string {
  const unit = `minecraft-server-${server}`;
  const sctl = systemctl([`is-active`, `${unit}.service`]);
  const state = sctl.ok ? sctl.out : "inactive";
  const apiInfo = apiStatus(api, server);

  const dataDir = findServerLogDir();
  const logPath = dataDir ? join(dataDir, server, "logs", "latest.log") : "";
  let done = "not yet";
  if (logPath && existsSync(logPath)) {
    const text = readFileSync(logPath, "utf-8");
    const m = /Done \(([0-9.]+)s\)!/.exec(text);
    if (m) done = `Done in ${m[1]}s`;
    else if (state === "active") done = "booting…";
  }

  const lines: string[] = [`server: ${server}`, `unit: ${unit}.service`, `state: ${state}`];
  if (apiInfo) {
    if (apiInfo.players) lines.push(`players: ${apiInfo.players}`);
    if (apiInfo.uptime) lines.push(`since: ${apiInfo.uptime}`);
  }
  lines.push(`boot: ${done}`);
  if (state === "failed") {
    const crashDir = dataDir ? join(dataDir, server, "crash-reports") : "";
    const crash = crashDir ? newestFile(crashDir) : null;
    if (crash) lines.push(`crash report: ${crash}`);
    // Pull the last error-ish lines from journald for a diagnosis.
    const j = systemctl([`--no-pager`, `-n`, `30`, `-u`, `${unit}.service`, `--output=cat`]);
    if (j.ok && j.out) lines.push(`\njournal (last 30):\n${j.out.split("\n").slice(-30).join("\n")}`);
  }
  return lines.join("\n");
}

// ── Boot monitor + crash diagnosis ───────────────────────────────────────────
// Genuine boot-abort patterns. NOTE: "Attempted to load class
// net/minecraft/client/... for invalid dist DEDICATED_SERVER" and "@Mixin
// target ... was not found" lines are NOT fatal — they are expected noise on a
// NeoForge dedicated server whenever client-only mods are present (the
// RuntimeDistCleaner/DISTXFORM phase + mixin warnings) and the server still
// reaches Done. They were once in this regex and caused false "fatal error,
// mod loads client-only classes (unknown)" reports mid-boot.
const SERVER_FATAL_RE = /Failed to (create mod instance|register automatic subscribers)\. ModID: (\w+)|Mod loading has failed|NoClassDefFoundError|Read-only file system|AccessDeniedException/;

function diagnose(text: string): string {
  const lines = text.split("\n").slice(-80);
  const hints: string[] = [];

  if (/Failed to (create mod instance|register automatic subscribers)\. ModID: (\w+)/.test(text)) {
    const m = /Failed to (?:create mod instance|register automatic subscribers)\. ModID: (\w+)/.exec(text);
    const modid = m ? m[1] : "(unknown — search the pack's mods/ for a client-only mod)";
    const registrationBug =
      /no @SubscribeEvent methods, but register was called anyway|NoSuchMethodError/.test(text);
    if (registrationBug) {
      // A mod bug, NOT a client-class problem. NeoForge throws this when a mod
      // calls NeoForge.EVENT_BUS.register(this) but the class has no
      // @SubscribeEvent methods (see mc-mod-patch for a real case). Marking it
      // side = "client" would be wrong — it aborts on the server too and the
      // fix is a jar/source patch, not a side flag.
      hints.push(
        `A mod failed to load on the dedicated server (mod '${modid}'): the boot abort is a COMPILED-LOGIC mod bug, not a client-class issue. ` +
        `The log shows a @SubscribeEvent/NoSuchMethodError failure (e.g. "no @SubscribeEvent methods, but register was called anyway"), which a mod raises when it registers an event listener on a class with no @SubscribeEvent methods. ` +
        `Do NOT mark it side = "client" — that only drops client-only mods from the server's side filter and would wrongly remove its required server-side content (e.g. Minecolonies blueprints). ` +
        `Fix it with a jar patch (modules/nixos/minecraft-server/modpacks/<pack>/patches/, see the mc-mod-patch skill) or a source patch, then packwiz refresh and rebuild the server.`
      );
    } else {
      hints.push(
        `A mod failed to load on the dedicated server (mod '${modid}'). ` +
        `If log lines above show "invalid dist DEDICATED_SERVER" or a missing client class, ` +
        `it likely loads client-only classes: find its modules/nixos/minecraft-server/modpacks/<pack>/mods/*.pw.toml and check 'side'. ` +
        `Client-only mods must be side = "client" (not "both") so the server's side filter drops them; the Prism client keeps them. ` +
        `Then: packwiz refresh, rebuild the server.` +
        `\nNote: standalone "Attempted to load class ... for invalid dist DEDICATED_SERVER" / "Mixin target ... was not found" lines are benign noise — only treat this as fatal when boot actually aborts with this ModID error.`
      );
    }
  }
  if (/NoClassDefFoundError/.test(text)) {
    hints.push(`NoClassDefFoundError — a mod expects a library/class not present on the server classpath (e.g. LWJGL, commons-compress). Usually a client-only mod. Same fix: mark it side = "client".`);
  }
  if (/Read-only file system|AccessDeniedException.*config/.test(text)) {
    hints.push(`The server cannot write its config/ (read-only). This is a module bug — packwizStartPre must seed config/ and defaultconfigs/ as writable dirs (rsync --ignore-existing + chmod u+w), not symlink the store path. Check modules/nixos/minecraft-server/config.nix.`);
  }
  if (/Permission denied.*sudo|sudo:.*Permission denied/.test(text)) {
    hints.push(`sudo permission denied for the web/management user — it needs wheel membership (users.users.<web-user>.extraGroups = [ "wheel" ]) to exec the setuid sudo wrapper.`);
  }
  if (hints.length === 0) {
    hints.push(`No auto-diagnosis matched. Look for the first 'ERROR' or 'Exception' block above, or the newest crash report in <dataDir>/<server>/crash-reports/.`);
  }
  return `\n\n── diagnosis ──\n${hints.join("\n\n")}`;
}

// The crash diagnosis must only fire when the server process has ACTUALLY
// died. A dedicated server still booting can log transient stack traces
// (RuntimeDistCleaner/DISTXFORM + mixin warnings for client-only mods) that
// match fatal-looking patterns; treating those as a crash is a false positive
// (the server then reaches Done). A unit is "dead" when systemd reports the
// service as failed/inactive, or the java process is no longer running.
function isProcessDead(unit: string): boolean {
  // systemd is the authoritative source: an active/activating unit is still
  // running, a failed/inactive one is not.
  const sctl = systemctl([`is-active`, `${unit}.service`]);
  if (sctl.ok) {
    const state = sctl.out.trim();
    if (state === "failed" || state === "inactive" || state === "deactivating" || state === "dead") return true;
    if (state === "active" || state === "activating" || state === "reloading") return false;
  }
  // Fallback: check the unit's MainPID is actually gone.
  const pid = execSync(`systemctl show ${unit}.service -p MainPID --value 2>/dev/null`, { encoding: "utf-8" }).trim();
  if (pid && pid !== "0") {
    try {
      process.kill(Number(pid), 0);
      return false; // PID exists
    } catch {
      return true; // PID gone
    }
  }
  return false;
}

async function waitForBoot(server: string, api: string | null, timeoutSec: number): Promise<string> {
  const unit = `minecraft-server-${server}`;
  const dataDir = findServerLogDir();
  const logPath = dataDir ? join(dataDir, server, "logs", "latest.log") : "";
  const start = Date.now();
  const waitMs = timeoutSec > 0 ? timeoutSec * 1000 : 1_200_000;
  let lastLen = 0;

  while (Date.now() - start < waitMs) {
    const sctl = systemctl([`is-active`, `${unit}.service`]);
    const unitFailed = sctl.ok && (sctl.out === "failed" || sctl.out === "inactive");
    if (unitFailed) {
      const j = systemctl([`--no-pager`, `-n`, `120`, `-u`, `${unit}.service`, `--output=cat`]);
      const logText = (logPath && existsSync(logPath)) ? readFileSync(logPath, "utf-8") : "";
      const src = j.out + "\n" + logText;
      return `mc-server: '${server}' FAILED to boot.\n\n${diagnose(src)}\n\n-- journal/log tail --\n${src.split("\n").slice(-60).join("\n")}`;
    }
    const text = (logPath && existsSync(logPath)) ? readFileSync(logPath, "utf-8") : "";
    const newChunk = text.slice(lastLen);
    lastLen = text.length;
    if (/Done \([0-9.]+s\)! For help/.test(text)) {
      const m = /Done \(([0-9.]+)s\)!/.exec(text);
      return `mc-server: '${server}' booted (Done in ${m ? m[1] + "s" : "?"}). ${Math.round((Date.now() - start) / 1000)}s elapsed.`;
    }
    // Only report a fatal error when the process has ACTUALLY died. A bare
    // stack-trace match on a still-running unit mid-boot is usually benign
    // DISTXFORM/mixin noise (client-only mods on a dedicated server) and the
    // server reaches Done directly after — reporting it as fatal is a
    // false positive.
    if (SERVER_FATAL_RE.test(newChunk) && isProcessDead(unit)) {
      return `mc-server: '${server}' hit a fatal error:\n\n${diagnose(text)}\n\n-- log tail --\n${text.split("\n").slice(-60).join("\n")}`;
    }
    await sleep(3000);
  }
  return `mc-server: '${server}' did not finish booting within ${Math.round(waitMs / 1000)}s. Last log tail:\n${(logPath && existsSync(logPath) ? readFileSync(logPath, "utf-8") : "(no latest.log yet)").split("\n").slice(-30).join("\n")}`;
}

// ── Performance ──────────────────────────────────────────────────────────────
// Reports live resource usage + health signals for a server, drawn from the
// systemd cgroup (memory/CPU), the server log (TPS / "Can't keep up" / players),
// and the dashboard API. No mod required — the log's periodic tick lag warnings
// are the TPS proxy.
function perf(server: string, api: string | null): string {
  const unit = `minecraft-server-${server}`;
  const dataDir = findServerLogDir();
  const logPath = dataDir ? join(dataDir, server, "logs", "latest.log") : "";
  const lines: string[] = [`server: ${server}`, `unit: ${unit}.service`];

  // systemd cgroup memory + CPU.
  const memCurrent = execSync(`systemctl show ${unit}.service -p MemoryCurrent --value 2>/dev/null`, { encoding: "utf-8" }).trim();
  const memMax = execSync(`systemctl show ${unit}.service -p MemoryMax --value 2>/dev/null`, { encoding: "utf-8" }).trim();
  const cpuNS = execSync(`systemctl show ${unit}.service -p CPUUsageNSec --value 2>/dev/null`, { encoding: "utf-8" }).trim();
  const cpuMax = execSync(`systemctl show ${unit}.service -p CPUQuotaPerSecUSec --value 2>/dev/null`, { encoding: "utf-8" }).trim();
  const nproc = execSync(`nproc 2>/dev/null`, { encoding: "utf-8" }).trim();

  const fmtMB = (b: string) => (b && Number(b) > 0 ? `${(Number(b) / 1073741824).toFixed(1)}G` : b);
  lines.push(`memory: ${fmtMB(memCurrent)} used` + (memMax && memMax !== "infinity" ? ` / ${fmtMB(memMax)} cap` : " (no cap)"));
  if (cpuMax && cpuMax !== "infinity") {
    const pct = Number(cpuMax) / 1000000;
    lines.push(`cpu: ${pct}% quota` + (nproc ? ` of ${nproc} cores` : ""));
  }
  if (cpuNS && Number(cpuNS) > 0) {
    lines.push(`cpu time: ${(Number(cpuNS) / 1e9).toFixed(0)}s total`);
  }

  // TPS proxy + overload warnings from the server log.
  if (logPath && existsSync(logPath)) {
    const text = readFileSync(logPath, "utf-8");
    const overloads = [...text.matchAll(/Can't keep up!.*?Running (\d+)ms or (\d+) ticks behind/g)].slice(-5);
    if (overloads.length) {
      const recent = overloads.map((m) => `${m[2]} ticks behind (${(Number(m[1]) / 1000).toFixed(1)}s)`).join("; ");
      lines.push(`overload (last ${overloads.length}): ${recent}`);
    } else {
      lines.push("overload warnings: none in log");
    }
    const joined = [...text.matchAll(/(\w+) joined the game/g)].slice(-5).map((m) => m[1]);
    if (joined.length) lines.push(`recent joins: ${joined.join(", ")}`);
  }

  const apiInfo = apiStatus(api, server);
  if (apiInfo) {
    if (apiInfo.players) lines.push(`players: ${apiInfo.players}`);
  }

  // Host-level context: total memory pressure (the server shares the box).
  try {
    const free = execSync(`free -g | awk '/Mem:/{print $2"G total, "($2-$7)"G used, "$7"G avail"} /Swap:/{print "swap: "$2"G total, "$3"G used"}' 2>/dev/null`, { encoding: "utf-8" }).trim();
    if (free) lines.push(`host: ${free.replace(/\n/g, " | ")}`);
  } catch { /* ignore */ }

  return lines.join("\n");
}

// ── Top-level ────────────────────────────────────────────────────────────────
async function run(
  repo: string,
  server: string,
  action: string,
  timeout: number,
  api: string | null
): Promise<string> {
  const unit = `minecraft-server-${server}`;

  switch (action) {
    case "status":
      return status(repo, server, api);
    case "start": {
      const viaApi = apiAction(api, server, "start");
      if (viaApi !== null && !viaApi.includes("error")) {
        return `mc-server: start requested for '${server}' via dashboard API (${viaApi}).`;
      }
      const r = systemctl([`start`, `${unit}.service`]);
      return r.ok ? `mc-server: started ${unit}.service` : `mc-server: failed to start:\n${r.out}`;
    }
    case "stop": {
      const viaApi = apiAction(api, server, "stop");
      if (viaApi !== null && !viaApi.includes("error")) {
        return `mc-server: stop requested for '${server}' via dashboard API (${viaApi}). Note: graceful stop saves the world and can take a while.`;
      }
      const r = systemctl([`stop`, `${unit}.service`]);
      return r.ok ? `mc-server: stopped ${unit}.service` : `mc-server: failed to stop:\n${r.out}`;
    }
    case "restart": {
      const viaApi = apiAction(api, server, "restart");
      if (viaApi !== null && !viaApi.includes("error")) {
        return `mc-server: restart requested for '${server}' via dashboard API (${viaApi}).`;
      }
      const r = systemctl([`restart`, `${unit}.service`]);
      return r.ok ? `mc-server: restarted ${unit}.service` : `mc-server: failed to restart:\n${r.out}`;
    }
    case "boot":
      return waitForBoot(server, api, timeout);
    case "perf":
      return perf(server, api);
    case "list":
      return `mc-server: configured servers: ${listServers(repo).join(", ") || "(none)"}`;
    default:
      return `mc-server: unknown action '${action}'. Use status|start|stop|restart|boot|perf|list.`;
  }
}

export default {
  description:
    "Manage a dedicated Minecraft server defined in this repo (modules/nixos/minecraft-server/servers/). Actions: status (state, players, uptime, boot progress), start, stop, restart, boot (start the unit and wait for 'Done', diagnosing crashes), perf (live memory/CPU from the systemd cgroup + TPS/overload/players from the log — no mod required), list (configured servers). Uses the minecraft-server module's dashboard API on loopback when reachable, else falls back to systemctl. Diagnoses the two common dedicated-server boot failures: a client-only mod marked side = \"both\" (crashes with client-only class loads — fix by setting side = \"client\"), and read-only config dirs.",
  args: {
    server: {
      type: "string",
      description: "Server name (e.g. 'allthetech'). 'list' shows configured servers.",
    },
    action: {
      type: "string",
      description: "status (default) | start | stop | restart | boot (start + wait for 'Done' with crash diagnosis) | perf (memory/CPU/TPS/overload/players) | list.",
    },
    modpack: {
      type: "string",
      description: "Optional modpack name to resolve the server from (scans servers/ for packwiz wiring). Ignored if 'server' is given.",
    },
    timeout: {
      type: "number",
      description: "Seconds to wait when action=boot (default 1200; a large pack's first boot can take 10+ min).",
    },
    note: {
      type: "string",
      description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill.md).",
    },
  },
  async execute(args: { server?: string; action?: string; modpack?: string; timeout?: number; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const action = args.action || "status";

    if (action === "list") {
      return `mc-server: configured servers: ${listServers(repo).join(", ") || "(none)"}`;
    }
    if (!args.server && args.modpack) {
      const hits = serversForPack(repo, args.modpack);
      if (hits.length === 1) {
        args.server = hits[0];
      } else if (hits.length > 1) {
        return `mc-server: modpack '${args.modpack}' is wired to multiple servers (${hits.join(", ")}). Pass server= explicitly.`;
      } else {
        return `mc-server: no server in modules/nixos/minecraft-server/servers/ is wired to modpack '${args.modpack}'.`;
      }
    }
    if (!args.server) {
      const servers = listServers(repo);
      if (servers.length === 0) return "mc-server: no server definitions found in modules/nixos/minecraft-server/servers/.";
      return `mc-server: provide a server name. Configured servers: ${servers.join(", ")}.`;
    }
    const api = apiBase();
    return run(repo, args.server, action, args.timeout || 0, api);
  },
};

// ## RUN LOG
// ### 2026-08-21
// Checking available servers before optimization

// ## RUN LOG
// ### 2026-08-21
// list servers

// ## RUN LOG
// ### 2026-08-21
// Checking server status before optimization

// ## RUN LOG
// ### 2026-08-21
// Checking server performance metrics

// ## RUN LOG
// ### 2026-08-21
// Verifying server optimizations are applied

// ## RUN LOG
// ### 2026-08-27
// Checking current running Minecraft instances

// ## RUN LOG
// ### 2026-08-27
// Checking current running Minecraft instances

// ## RUN LOG
// ### 2026-08-27
// Checking ATM11 instance status
