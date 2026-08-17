import type { Plugin } from "@opencode-ai/plugin";
import { homedir } from "node:os";
import { join } from "node:path";
import { existsSync, readFileSync } from "node:fs";

// Self-improvement guard for the build agent.
//
// The build agent's prompt (modules/home/opencode/agents/build.md) bakes a
// SELF_IMPROVE=true toggle that makes a post-task self-improvement CHECKPOINT
// mandatory: the agent must explicitly evaluate — before the final summary —
// whether this run produced a grounded lesson and either call
// `goals_learning_append` or explicitly state "no lessons this run". The
// checkpoint is required to be CONSIDERED, never to force a proposal (forcing
// an append every run would manufacture noise). The prompt alone is soft:
// nothing at runtime enforces that the checkpoint actually happened. This
// sibling plugin closes that loop:
//
//   * When a session goes idle, look the session up in opencode.db's `session`
//     table. If its `agent` is `build` (the primary development agent whose
//     prompt carries the toggle)...
//   * ...and the repo's live `agents/build.md` still says SELF_IMPROVE=true
//     (the prompt itself tells agents to read the current value rather than
//     trust a stale baked copy)...
//   * ...and the session NEVER satisfied the checkpoint (no completed
//     `goals_learning_append` / `learning_append` tool call AND no explicit
//     "no lessons this run" statement — scan the `part` table)...
//   * ...inject one reminder message into the session asking it to complete
//     the checkpoint before the final summary (propose or declare no lessons).
//
// It is deliberately a *reminder*, not a blocker: it never edits the session,
// never changes agent config, and never calls any goals tool. It mirrors the
// pattern proven in plugins/triage-capture.ts (bun:sqlite with node:sqlite
// fallback, direct `part`-table reads because the SDK's session.messages API
// returns empty for another session at idle time).

function opencodeDbPath(): string {
  return process.env.SELF_IMPROVE_OPENCODE_DB ?? join(homedir(), ".local", "share", "opencode", "opencode.db");
}

// The plugin runs inside opencode's bundled Bun runtime, which provides
// `bun:sqlite` but NOT `node:sqlite` (verified in triage-capture.ts). Fall
// back to node:sqlite anyway so the same file runs on a plain-node host.
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

// Find the build agent's prompt file relative to the project directory. The
// plugin's `directory` points at the opened project root (this flake), so the
// agent prompt lives under modules/home/opencode/agents/build.md.
function buildPromptPath(directory: string): string | null {
  const candidates = [
    join(directory, "modules", "home", "opencode", "agents", "build.md"),
    // Allow running from a worktree or a subdir of the checkout.
    join(directory, "..", "modules", "home", "opencode", "agents", "build.md"),
  ];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  return null;
}

function selfImproveEnabled(directory: string): boolean {
  const p = buildPromptPath(directory);
  if (!p) return false;
  try {
    const text = readFileSync(p, "utf-8");
    return /SELF_IMPROVE\s*=\s*true/.test(text);
  } catch {
    return false;
  }
}

// Did this session satisfy the self-improvement checkpoint? That is: it either
// recorded a completed `goals_learning_append` / `learning_append` tool call,
// OR it explicitly declared "no lessons this run" (the build prompt's
// checkpoint semantics: required to CONSIDER, never forced to propose). A
// completed append call or an explicit no-lessons statement both mean the
// checkpoint ran; only when NEITHER appears should the guard remind.
function checkpointSatisfied(db: any, kind: string, sessionID: string): boolean {
  const rows = queryAll(
    db,
    kind,
    "SELECT data FROM part WHERE session_id = ?",
    sessionID,
  );
  for (const row of rows) {
    let data: any;
    try {
      data = typeof row.data === "string" ? JSON.parse(row.data) : row.data;
    } catch {
      continue;
    }
    if (data?.type === "tool") {
      const tool = data.tool ?? "";
      if (tool === "learning_append" || tool === "goals_learning_append") {
        if (data.state?.status === "completed") return true;
      }
    }
    if (data?.type === "text") {
      const text = typeof data.text === "string" ? data.text : "";
      if (/no lessons this run/i.test(text) || /no lessons\.?$/im.test(text.trim())) return true;
    }
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

      // Only guard the build agent (the primary agent whose prompt carries
      // SELF_IMPROVE). Triage/build subagents don't run the pass.
      let agent: string | null = null;
      try {
        const open = await openDb(opencodeDbPath());
        try {
          agent =
            queryGet(open.db, open.kind, "SELECT agent FROM session WHERE id = ?", sessionID)?.agent ?? null;
        } finally {
          open.db.close();
        }
      } catch {
        return;
      }
      if (agent !== "build") return;

      // Honour the live toggle: read the current value from the repo rather
      // than trusting a stale baked copy (exactly what the prompt tells the
      // agent to do).
      if (!selfImproveEnabled(directory)) return;

      // If the checkpoint already ran (a completed append call, or an explicit
      // "no lessons this run" statement), nothing to do.
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
                "but neither a goals_learning_append call nor an explicit 'no lessons this run' " +
                "statement was recorded. Before your final summary, complete the self-improvement " +
                "checkpoint: either capture any grounded lesson via `goals_learning_append` or " +
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