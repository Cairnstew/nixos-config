import type { Plugin } from "@opencode-ai/plugin";
import { homedir } from "node:os";
import { join } from "node:path";
import { existsSync } from "node:fs";

// Tier 1 Task 4 — transcript-capture plugin for ensemble triage verdicts.
//
// The `learning_review` MCP tool inserts a `review_verdicts` row with only
// `learning_id` + `verdict` (reviewer_role stays NULL). This sibling plugin
// observes the reviewer session that made that call and back-fills the row
// with `reviewer_role`, `rederivation_method`, `transcript_ref`, and
// `match_confidence` — all from the session's own transcript, without the
// reviewer being asked to report any of it. It is observe-only: it never
// touches `learnings.status` / `acted_on_commit`, and it never edits the
// running session.
//
// Matching rules (kept deliberately strict):
//   * Only tool parts that COMPLETED and whose `tool` is a known re-derivation
//     method count as evidence of re-derivation. `read` / `grep` / `nix-eval` /
//     `nix-graph_*` are the allowlist; `bash` / `edit` are NOT re-derivation in
//     the Decision-3 sense (they are the reviewer's own exploration, not a
//     check that the evidence's file:line still holds). A captured `read` is as
//     server-sourced as a captured `grep` — same structured ToolPart, tool
//     name, input path, and output content, none of it model-authored.
//   * match_confidence is "high" when a qualifying call's INPUT arguments
//     (command/pattern/attr) reference the learning's `evidence` text, i.e.
//     they re-derive that exact evidence; "low" when qualifying calls happened
//     but none of them referenced the evidence text; NULL when no qualifying
//     call happened at all (the verdict row then counts as `uncertain` per the
//     review_verdicts invariant).
//   * transcript_ref = "session:<sessionID>;call:<callID>" of the FIRST
//     qualifying call, enough to look the raw record up in opencode.db again.

// Re-derivation methods as opencode exposes them (MCP tools carry the server
// prefix, e.g. `nix_graph_get_dependents` from the nix-graph MCP server).
// Built-in/core tools are intentionally excluded.
const REDERIVATION_TOOLS: Record<string, string> = {
  read: "read",
  nix_eval: "nix-eval",
  grep: "grep",
  nix_graph_get_dependents: "nix-graph",
  nix_graph_get_option_definers: "nix-graph",
  nix_graph_get_definers: "nix-graph",
  nix_graph_find_mkforce_sites: "nix-graph",
  nix_graph_find_namespace_violations: "nix-graph",
  nix_graph_find_path: "nix-graph",
  nix_graph_node_info: "nix-graph",
  nix_graph_search_nodes: "nix-graph",
  nix_graph_graph_stats: "nix-graph",
};

function goalsDbPath(): string {
  return process.env.TRIAGE_CAPTURE_GOALS_DB ?? join(homedir(), ".local", "share", "goals", "goals.db");
}

function ensembleDbPath(): string {
  return process.env.TRIAGE_CAPTURE_ENSEMBLE_DB ?? join(homedir(), ".config", "opencode", "ensemble.db");
}

// The plugin runs inside opencode's bundled Bun runtime, which provides
// `bun:sqlite` but NOT `node:sqlite` (verified live, opencode 1.18.13 / Bun
// 1.3.14). Fall back to node:sqlite anyway so the same file runs on a
// plain-node plugin host.
async function openDb(path: string, readonly = false): Promise<{ db: any; kind: string }> {
  try {
    const { Database } = await import("bun:sqlite");
    const db = readonly ? new Database(path, { readonly: true }) : new Database(path);
    return { db, kind: "bun" };
  } catch (e) {
    const { DatabaseSync } = await import("node:sqlite");
    const db = readonly ? new DatabaseSync(path, { readOnly: true }) : new DatabaseSync(path);
    return { db, kind: "node" };
  }
}

function queryGet(db: any, kind: string, sql: string, ...params: any[]): any | undefined {
  if (kind === "bun") return db.query(sql).get(...params);
  return db.prepare(sql).get(...params);
}

function queryRun(db: any, kind: string, sql: string, ...params: any[]): void {
  if (kind === "bun") db.query(sql).run(...params);
  else db.prepare(sql).run(...params);
}

// Map an opencode tool name to a method name, or null if not a re-derivation
// method. Accepts both `nix_graph_*` (MCP server prefix) and bare names.
function methodForTool(tool: string): string | null {
  if (tool in REDERIVATION_TOOLS) return REDERIVATION_TOOLS[tool];
  if (tool.startsWith("nix_graph_")) return "nix-graph";
  if (tool === "nix-graph" || tool === "nix-eval" || tool === "grep" || tool === "read") return tool;
  return null;
}

function serializeInput(input: unknown): string {
  try {
    return JSON.stringify(input ?? {});
  } catch {
    return String(input ?? "");
  }
}

// Does a qualifying call's input reference the learning's evidence text?
// Evidence is typically a `path:line (note)` string; we treat it as a
// reference if any non-trivial token of the input appears verbatim in the
// evidence. A pure "file exists" exploration is not a reference.
//
// `read` matches the same shape as grep/nix-eval: its INPUT arguments are
// `{ filePath }`, so "references the evidence" means the read path equals one
// of the `path:line` paths cited in the evidence (matching by file, not by
// line — the reviewer read the cited file, which re-derives that citation).
// This lives in the same function as the generic token match so the high/low
// decision stays a single code path for every method.
function referencesEvidence(input: unknown, evidence: string): boolean {
  if (!evidence || !input) return false;
  const inputObj = typeof input === "object" ? (input as Record<string, unknown>) : {};

  // read: `{ filePath }` must match a path cited in the evidence.
  const filePath = typeof inputObj.filePath === "string" ? inputObj.filePath : "";
  if (filePath) {
    for (const path of evidencePaths(evidence)) {
      // Match the cited file exactly (relative paths, or the absolute form
      // reviewers actually pass to `read`). Boundary-matched so a read of
      // `other-config.nix` does not count as re-deriving `config.nix`. Line
      // range is ignored — reading the file re-derives the citation regardless
      // of which line was opened.
      if (filePath === path || filePath.endsWith(`/${path}`)) return true;
    }
  }

  const inputStr = serializeInput(input);
  if (!inputStr) return false;
  const tokens = inputStr.match(/[A-Za-z0-9_./:#@+=-]{8,}/g) ?? [];
  for (const tok of tokens) {
    if (evidence.includes(tok)) return true;
  }
  return false;
}

// Extract the `path:line` citations from an evidence string like
// `modules/foo/bar.nix:18-26 (note); modules/foo/baz.nix:5` → the list of
// file paths. Uses the same shape as the reviewer-facing evidence format.
function evidencePaths(evidence: string): string[] {
  const paths: string[] = [];
  const re = /([A-Za-z0-9_./@-]+\.(?:nix|json|toml|py|md|sh|conf|css))\s*:/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(evidence)) !== null) paths.push(m[1]);
  return paths;
}

export const TriageCapturePlugin: Plugin = async ({ client }) => {
  let goalsDb: any | null = null;
  let goalsKind = "bun";

  async function goalsConn(): Promise<{ db: any; kind: string }> {
    if (!goalsDb) {
      const c = await openDb(goalsDbPath());
      goalsDb = c.db;
      goalsKind = c.kind;
    }
    return { db: goalsDb, kind: goalsKind };
  }

  return {
    event: async ({ event }) => {
      if (event.type !== "message.part.updated") return;
      const part = (event as any).properties?.part;
      if (!part || part.type !== "tool") return;

      const toolPart = part as any;
      if (toolPart.tool !== "learning_review" && toolPart.tool !== "goals_learning_review") return;
      if (toolPart.state?.status !== "completed") return;

      const sessionID = toolPart.sessionID;
      const callID = toolPart.callID;

      try {
        const input = typeof toolPart.state.input === "object" ? toolPart.state.input : {};
        const learningId = Number(input.learning_id);
        if (!Number.isFinite(learningId)) return;

        const { db, kind } = await goalsConn();

        // The review_verdicts row just inserted by learning_review has
        // reviewer_role/rederivation_method/transcript_ref/match_confidence
        // all NULL; fill the most recent such row for this learning.
        const row = queryGet(
          db,
          kind,
          `SELECT id FROM review_verdicts
            WHERE learning_id = ? AND rederivation_method IS NULL
            ORDER BY id DESC LIMIT 1`,
          learningId,
        );
        if (!row) return;

        const role = await reviewerRoleFor(sessionID);
        const evidenceRow = queryGet(db, kind, "SELECT evidence FROM learnings WHERE id = ?", learningId);
        const evidence = evidenceRow?.evidence ?? "";

        // Scan the reviewer's own transcript for qualifying re-derivation
        // calls that came BEFORE this verdict call.
        let method: string | null = null;
        let ref: string | null = null;
        let sawQualifying = false;
        let referenced = false;

        try {
          const msgs = await client.session.messages({ path: { id: sessionID } });
          const arr = Array.isArray(msgs) ? msgs : [];
          for (const msg of arr) {
            const parts: any[] = Array.isArray((msg as any).parts) ? (msg as any).parts : [];
            for (const p of parts) {
              if (p?.type !== "tool") continue;
              const m = methodForTool(p.tool ?? "");
              if (!m) continue;
              if (p.state?.status !== "completed") continue;
              if (p.sessionID !== sessionID) continue;
              if (p.id === toolPart.id) continue; // the verdict call itself
              sawQualifying = true;
              if (referencesEvidence(p.state.input, evidence)) {
                referenced = true;
                if (!ref) ref = `session:${sessionID};call:${p.callID}`;
                if (!method) method = m;
              }
            }
          }
        } catch {}

        const confidence: "high" | "low" | null = !sawQualifying ? null : referenced ? "high" : "low";

        queryRun(
          db,
          kind,
          `UPDATE review_verdicts
              SET reviewer_role = ?, rederivation_method = ?, transcript_ref = ?, match_confidence = ?
            WHERE id = ?`,
          role,
          method,
          ref,
          confidence,
          row.id,
        );
      } catch {}
    },
  };

  async function reviewerRoleFor(sessionID: string): Promise<string | null> {
    const path = ensembleDbPath();
    if (!existsSync(path)) return null;
    try {
      const { db, kind } = await openDbReadonly(path);
      const row = queryGet(db, kind, "SELECT name FROM team_member WHERE session_id = ?", sessionID);
      db.close();
      return row ? row.name : null;
    } catch {
      return null;
    }
  }

  async function openDbReadonly(path: string): Promise<{ db: any; kind: string }> {
    try {
      const { Database } = await import("bun:sqlite");
      return { db: new Database(path, { readonly: true }), kind: "bun" };
    } catch {
      const { DatabaseSync } = await import("node:sqlite");
      return { db: new DatabaseSync(path, { readOnly: true }), kind: "node" };
    }
  }
};
