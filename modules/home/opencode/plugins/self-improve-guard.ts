import type { Plugin } from "@opencode-ai/plugin";
import { homedir } from "node:os";
import { join } from "node:path";
import { existsSync, readFileSync } from "node:fs";

// Self-improvement guard for the checkpoint-carrying primary agents (build,
// researcher).
//
// The agents' prompts (modules/home/opencode/agents/{build,researcher}.md) bake
// a SELF_IMPROVE=true toggle that makes a post-task self-improvement CHECKPOINT
// mandatory: before the final summary the agent must explicitly evaluate whether
// this run produced a grounded lesson and either apply it (an append-only,
// evidence-backed edit committed as its OWN commit via the mechanical
// commit-helper tools/self-improve-commit.sh, carrying a "Self-Improve:" trailer)
// or explicitly state "no lessons this run". The checkpoint is required to be
// CONSIDERED, never to force an apply (forcing one every run manufactures noise).
// The prompt alone is soft: nothing at runtime enforces that the checkpoint
// actually happened. This sibling plugin closes that loop:
//
//   * When a session goes idle, look the session up in opencode.db's `session`
//     table. If its `agent` is `build` or `researcher` (the agents whose prompts
//     carry the toggle)...
//   * ...and the repo's live agent prompt still says SELF_IMPROVE=true (the
//     prompt itself tells agents to read the current value rather than trust a
//     stale baked copy)...
//   * ...and the session NEVER satisfied the checkpoint (no explicit "no lessons
//     this run" statement, and no "Self-Improve:" commit-trailer in its
//     transcript — i.e. no self-apply was made)...
//   * ...inject one reminder message into the session asking it to complete the
//     checkpoint before the final summary (apply or declare no lessons).
//
// It is deliberately a *reminder*, not a blocker: it never edits the session,
// never changes agent config, and never calls any goals tool (the goals MCP
// exposes no self-improvement tools anymore). It reads the transcript from
// opencode.db's `part` table (bun:sqlite with node:sqlite fallback) because the
// SDK's session.messages API returns empty for another session at idle time.

function opencodeDbPath(): string {
  return process.env.SELF_IMPROVE_OPENCODE_DB ?? join(homedir(), ".local", "share", "opencode", "opencode.db");
}

// The plugin runs inside opencode's bundled Bun runtime, which provides
// `bun:sqlite` but NOT `node:sqlite` (verified in the retired triage-capture).
// Fall back to node:sqlite anyway so the same file runs on a plain-node host.
async function openDb(path: string): Promise<{ db: any; kind: string }> {
  try {
    const { Database } = await import("bun:sqlite");
    return { db: new Database(path, { readonly: true }), kind: "bun" };
  } catch {
    const { DatabaseSync } = await import("node:sqlite");
    return { db: new DatabaseSync(path, { readOnly: true }), kind: "node" };
  }
}

function queryGet(db: any, kind: string, sql: string, ...params: any[]): any | undefined {
  if (kind === "bun") return db.query(sql).get(...params);
  return db.prepare(sql).get(...params);
}

function queryAll(db: any, kind: string, sql: string, ...params: any[]): any[] {
  if (kind === "bun") return db.query(sql).all(...params);
  return db.prepare(sql).all(...params);
}

// The primary agents whose prompts carry the checkpoint toggle.
const CHECKPOINT_AGENTS = ["build", "researcher"] as const;

// The prompt for a given checkpoint agent lives under modules/home/opencode/agents/.
function agentPromptPath(directory: string, agent: string): string | null {
  const candidates = [
    join(directory, "modules", "home", "opencode", "agents", `${agent}.md`),
    // Allow running from a worktree or a subdir of the checkout.
    join(directory, "..", "modules", "home", "opencode", "agents", `${agent}.md`),
  ];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  return null;
}

function selfImproveEnabled(directory: string, agent: string): boolean {
  const p = agentPromptPath(directory, agent);
  if (!p) return false;
  try {
    const text = readFileSync(p, "utf-8");
    return /SELF_IMPROVE\s*=\s*true/.test(text);
  } catch {
    return false;
  }
}

// Did this session satisfy the self-improvement checkpoint? Under the single
// lineage there is no learning tool to observe; a session satisfies it by either
// (a) explicitly declaring "no lessons this run" (the build/researcher prompt's
// checkpoint semantics: required to CONSIDER, never forced to propose), or
// (b) reporting a self-apply — a commit carrying the "Self-Improve:" trailer that
// the commit-helper stamps. Either means the checkpoint ran; only when NEITHER
// appears should the guard remind.
function checkpointSatisfied(db: any, kind: string, sessionID: string): boolean {
  const rows = queryAll(db, kind, "SELECT data FROM part WHERE session_id = ?", sessionID);
  for (const row of rows) {
    let data: any;
    try {
      data = typeof row.data === "string" ? JSON.parse(row.data) : row.data;
    } catch {
      continue;
    }
    if (data?.type !== "text") continue;
    const text = typeof data.text === "string" ? data.text : "";
    if (/no lessons this run/i.test(text) || /no lessons\.?$/im.test(text.trim())) return true;
    if (/self-improve:/i.test(text)) return true;
  }
  return false;
}

export const SelfImproveGuardPlugin: Plugin = async ({ client, directory }) => {
  return {
    event: async ({ event }) => {
      // session.idle fires when the agent loop finishes a turn and the session
      // goes quiet — the natural point to check whether the final-summary
      // self-improvement pass was skipped.
      if (event.type !== "session.idle") return;
      const sessionID = (event as any).properties?.sessionID;
      if (!sessionID) return;

      // Only guard the checkpoint-carrying agents (build, researcher).
      let agent: string | null = null;
      try {
        const open = await openDb(opencodeDbPath());
        try {
          agent = queryGet(open.db, open.kind, "SELECT agent FROM session WHERE id = ?", sessionID)?.agent ?? null;
        } finally {
          open.db.close();
        }
      } catch {
        return;
      }
      if (!agent || !CHECKPOINT_AGENTS.includes(agent as any)) return;

      // Honour the live toggle: read the current value from the repo rather
      // than trusting a stale baked copy (exactly what the prompt tells the
      // agent to do).
      if (!selfImproveEnabled(directory, agent)) return;

      // If the checkpoint already ran (a "no lessons this run" statement or a
      // "Self-Improve:" self-apply report), nothing to do.
      let alreadyRan = false;
      try {
        const open = await openDb(opencodeDbPath());
        try {
          alreadyRan = checkpointSatisfied(open.db, open.kind, sessionID);
        } finally {
          open.db.close();
        }
      } catch {
        return;
      }
      if (alreadyRan) return;

      try {
        await client.session.prompt({
          sessionID,
          parts: [
            {
              type: "text",
              text:
                "Reminder (self-improve-guard): this session's agent has SELF_IMPROVE=true " +
                "but neither a self-improvement commit (a 'Self-Improve:' trailer via " +
                "tools/self-improve-commit.sh) nor an explicit 'no lessons this run' statement " +
                "was recorded. Before your final summary, complete the checkpoint: capture any " +
                "grounded lesson against an allow-listed target through the commit-helper, or " +
                "explicitly state 'no lessons this run' if the checkpoint produced nothing " +
                "concrete.",
              synthetic: true,
            },
          ],
        });
      } catch {
        // Non-fatal — opencode may reject injecting into an idle session.
      }
    },
  };
};