#!/usr/bin/env python3
"""
opencode-ensemble.py — build-time patch of the vendored opencode-ensemble fork.

Patches the PUBLISHED dist/index.js of @hueyexe/opencode-ensemble 0.16.1 (the
exact artifact the flake pins by sha256 — see FORK.md and fork.nix) to fix the
wake-path defect: every continuation turn (wake-lead, member delivery,
broadcast, shutdown nudge, watchdog/stall/peer nudges, pending-message wakes)
re-prompts a session with `promptAsync({ sessionID, parts })` and NO agent/model,
so the session silently falls back to the global default after turn one.

The patch (fail-loud, mirroring the modpack patch-jar.nix convention — if any
anchor is missing, this script exits non-zero and the Nix build fails loudly):

  1. Migration 9 — add `team.lead_model TEXT` (blanket ALTER, mechanism-native
     via the plugin's own MIGRATIONS/user_version machinery).
  2. team_create snapshot — after the team row INSERT, read the LEAD session's
     creation-time model from the opencode message table and store it in
     team.lead_agent / team.lead_model (best-effort; wake path has a fallback).
  3. Wrap all TEN wake `promptAsync({...})` call sites with
     `__ensembleWakeArgs(db, {...})`, which resolves the target session's
     agent/model (lead: team columns with message-table fallback; member:
     team_member columns) and attaches them to the continuation prompt.

Pages the raw dist because the artifact is sha256-pinned: exact-string anchors
are deterministic. Any upstream change to the pinned file breaks the anchors
loudly at build time instead of silently shipping a wrong patch.

Usage: python3 opencode-ensemble.py <input-dist.js> <output.js>
"""

import sys
import json

FAIL = "FORK-PATCH: expected anchor missing in %s: %r — the upstream pinned file changed; re-derive the patch anchor (see modules/home/opencode/FORK.md)"

# ── Injected helper block (module scope; uses the bundle's own module-scope
#    `__require` created via createRequire(import.meta.url)) ────────────────
HELPERS = """// ── FORK PATCH (wake-path fix) ────────────────────────────────────────────
// Vendored fork of @hueyexe/opencode-ensemble 0.16.1 — see FORK.md.
// Resolves the agent/model a session should CONTINUE on when a wake message
// re-prompts it. Without this every continuation falls back to the global
// default (the wake-path defect this fork fixes).
function __ensembleOpenCodeModel(sessionID) {
  // Best-effort creation-time model read from the opencode message table.
  // Used ONCE at team_create (snapshot) and as a fallback for legacy teams
  // whose team.lead_model is null. Returns null on any failure — the wake
  // path then degrades to today's default behavior (safe).
  try {
    if (!sessionID) return null
    const dbPath = process.env.ENSEMBLE_OPENCODE_DB ||
      (process.env.HOME || process.env.USERPROFILE || "~") + "/.local/share/opencode/opencode.db"
    let row = null
    if (typeof process.versions.bun === "string") {
      const { Database } = __require("bun:sqlite")
      const conn = new Database(dbPath, { readonly: true })
      const got = conn.query("SELECT data FROM message WHERE session_id = ? ORDER BY time_created ASC LIMIT 1").get(sessionID)
      row = got ? got.data : null
      conn.close()
    } else {
      const { DatabaseSync } = __require("node:sqlite")
      const conn = new DatabaseSync(dbPath, { readOnly: true })
      const got = conn.prepare("SELECT data FROM message WHERE session_id = ? ORDER BY time_created ASC LIMIT 1").get(sessionID)
      row = got ? got.data : null
      conn.close()
    }
    if (!row) return null
    const d = JSON.parse(row)
    if (!d || !d.model || !d.model.modelID) return null
    return { agent: d.agent || "build", model: d.model.providerID + "/" + d.model.modelID }
  } catch (err) {
    return null
  }
}
function __ensembleWakeArgs(db, opts) {
  // Wrap a wake prompt with the target session's resolved agent/model.
  // Lead: team.lead_agent / team.lead_model (null-model -> message fallback).
  // Member: team_member.agent / team_member.model ("provider/model" string).
  // Never throws: any unexpected DB state degrades to the current behavior.
  if (!db || !opts || !opts.sessionID) return opts
  try {
    let agent = null
    let model = null
    const lead = db.query("SELECT lead_agent, lead_model FROM team WHERE lead_session_id = ? AND status = 'active'").get(opts.sessionID)
    if (lead) {
      agent = lead.lead_agent
      model = lead.lead_model
      if (!model) {
        const lm = __ensembleOpenCodeModel(opts.sessionID)
        if (lm) {
          agent = lm.agent
          model = lm.model
        }
      }
    } else {
      const m = db.query("SELECT agent, model FROM team_member WHERE session_id = ?").get(opts.sessionID)
      if (m) {
        agent = m.agent
        model = m.model
      }
    }
    if (!agent && !model) return opts
    const out = Object.assign({}, opts)
    if (agent) out.agent = agent
    if (model) {
      const slash = model.indexOf("/")
      if (slash > 0) out.model = { providerID: model.slice(0, slash), modelID: model.slice(slash + 1) }
    }
    return out
  } catch (err) {
    return opts
  }
}
// ── END FORK PATCH ─────────────────────────────────────────────────────────
"""

# ── Migration 9 splice: the MIGRATIONS array ends with migration 8 without a
#    trailing comma; append our migration after it (keeps user_version native).
MIGRATION_ANCHOR = '   PRAGMA foreign_keys=ON;`\n];'
MIGRATION_REPLACEMENT = """   PRAGMA foreign_keys=ON;`,
  // Migration 9 (fork): track the lead's resolved model so wake
  // continuations preserve it (wake-path fix, FORK.md).
  `ALTER TABLE team ADD COLUMN lead_model TEXT;`
];"""

# ── team_create snapshot: insert right after the real team INSERT (the row is
#    keyed by the just-generated `id`; `sessionId` = lead session; `now` in scope).
TEAM_CREATE_ANCHOR = ('deps.db.run("INSERT INTO team (id, name, project_id, lead_session_id, status, delegate, time_created, time_updated) VALUES (?, ?, ?, ?, \'active\', 0, ?, ?)", [id, args.name, projectId, sessionId, now, now]);')
TEAM_CREATE_REPLACEMENT = TEAM_CREATE_ANCHOR + (
    "\n  // FORK PATCH: snapshot the lead's resolved model at creation so wake\n"
    "  // continuations preserve it (best effort; wake path falls back to the\n"
    "  // message-table read when lead_model is null).\n"
    '  try {\n'
    "    const __lm = __ensembleOpenCodeModel(sessionId)\n"
    "    if (__lm) {\n"
    '      deps.db.run("UPDATE team SET lead_agent = ?, lead_model = ?, time_updated = ? WHERE id = ?", [__lm.agent, __lm.model, now, id])\n'
    "    }\n"
    "  } catch (err) { /* best effort */ }"
)

# ── The ten wake call sites. dbvar is the ensemble DB handle in scope at that
#    site. Each OLD is the EXACT snippet of the pinned dist (verified 2026-08-26
#    against sha256 2f3268a2…09a4a98) — indentation included.
SITES = [
    ("recovery-redeliver", "db",
     'promptAsync({\n'
     '          sessionID: recipientSessionId,\n'
     '          parts: [{ type: "text", text: `[Recovered team message from ${msg.from_name}]: ${msg.content}` }]\n'
     '        })'),
    ("team-message wake-lead", "deps.db",
     'promptAsync({\n'
     '      sessionID: recipientSessionId,\n'
     '      parts: [{ type: "text", text: `[System: New team message from ${senderName}]` }]\n'
     '    })'),
    ("team-message member delivery", "deps.db",
     'promptAsync({\n'
     '    sessionID: recipientSessionId,\n'
     '    parts: [{ type: "text", text: deliveryText }]\n'
     '  })'),
    ("team-broadcast delivery", "deps.db",
     'promptAsync({\n'
     '      sessionID: recipient.sessionId,\n'
     '      parts: [{ type: "text", text: `[Team broadcast from ${senderName}]: ${args.text}` }]\n'
     '    })'),
    ("team-shutdown nudge", "deps.db",
     'promptAsync({\n'
     '      sessionID: member.session_id,\n'
     '      parts: [{\n'
     '        type: "text",\n'
     '        text: `[Shutdown requested]: The lead has requested you shut down. Finish your current task, send your final findings to the lead via team_message, then stop.`\n'
     '      }]\n'
     '    })'),
    ("watchdog stalled nudge", "this.db",
     'promptAsync({\n'
     '        sessionID: member.session_id,\n'
     '        parts: [{ type: "text", text: "[System]: You appear stalled — no progress detected. Report your current status to the lead via team_message, or wrap up your work." }]\n'
     '      })'),
    ("watchdog chatty nudge", "this.db",
     'promptAsync({\n'
     '        sessionID: member.session_id,\n'
     '        parts: [{ type: "text", text: "[System]: You\'ve sent several messages to teammates. Focus on completing your task and send your results to the lead via team_message." }]\n'
     '      })'),
    ("idle-without-report nudge", "db",
     'promptAsync({\n'
     '                sessionID,\n'
     '                parts: [{ type: "text", text: "[System]: You completed your work but did not report results. Send your findings to the lead via team_message now." }]\n'
     '              })'),
    ("pending-messages lead wake", "db",
     'promptAsync({\n'
     '                sessionID,\n'
     '                parts: [{ type: "text", text: `[System: ${pending.c} new team message(s) available]` }]\n'
     '              })'),
    ("pending peer-messages wake", "db",
     'promptAsync({\n'
     '                sessionID,\n'
     '                parts: [{ type: "text", text: `[System: ${peerMsgs.c} new message(s) from teammates]` }]\n'
     '              })'),
]


def patch(input_path: str, output_path: str) -> None:
    src = open(input_path, "r", encoding="utf-8").read()

    # 0. Essential module-scope anchors the injected helpers rely on.
    for anchor, label in [("import { createRequire } from \"node:module\";", "module import"),
                          ("var __require = /* @__PURE__ */ createRequire(import.meta.url);", "module __require"),
                          ("function parseModelId(", "parseModelId helper")]:
        if src.count(anchor) != 1:
            sys.exit(FAIL % (input_path, anchor[:60]))

    # 1. Inject helpers at module top (function declarations hoist; they only
    #    reference __require at call time, long after module init).
    if "__ensembleWakeArgs" in src:
        sys.exit("FORK-PATCH: output already patched — refusing to double-patch")
    src = src.replace("import { createRequire } from \"node:module\";\n",
                      "import { createRequire } from \"node:module\";\n" + HELPERS, 1)

    # 2. Migration 9 (blanket ALTER via the plugin's own migration machinery).
    if src.count(MIGRATION_ANCHOR) != 1:
        sys.exit(FAIL % (input_path, "MIGRATIONS array end"))
    src = src.replace(MIGRATION_ANCHOR, MIGRATION_REPLACEMENT, 1)

    # 3. team_create snapshot.
    if src.count(TEAM_CREATE_ANCHOR) != 1:
        sys.exit(FAIL % (input_path, "team_create INSERT INTO team row"))
    src = src.replace(TEAM_CREATE_ANCHOR, TEAM_CREATE_REPLACEMENT, 1)

    # 4. Wrap the ten wake sites. Each OLD is an exact `promptAsync({ ... })`
    #    object of the pinned dist; wrap it as
    #    `promptAsync(__ensembleWakeArgs(<db>, { ... }))`.
    for label, dbvar, old in SITES:
        if src.count(old) != 1:
            sys.exit("FORK-PATCH: wake site %r — expected exactly 1 occurrence, found %d"
                     % (label, src.count(old)))
        assert old.startswith("promptAsync({") and old.endswith("})")
        inner = old[len("promptAsync({"):-len("})")]
        src = src.replace(old, "promptAsync(__ensembleWakeArgs(" + dbvar + ", {" + inner + "}))", 1)

    # 5. Post-conditions (fail loud if the patch didn't take).
    if src.count("__ensembleWakeArgs(") != 11:  # 10 wrapped sites + 1 definition
        sys.exit("FORK-PATCH: expected 11 __ensembleWakeArgs( occurrences, found %d"
                 % src.count("__ensembleWakeArgs("))
    if src.count("ADD COLUMN lead_model") != 1:
        sys.exit("FORK-PATCH: lead_model migration missing")
    # The only remaining bare promptAsync({ must be the spawn site (already has agent/model).
    bare = src.count("promptAsync({")
    if bare != 1:
        sys.exit("FORK-PATCH: expected exactly 1 un-wrapped promptAsync({ (the spawn site), found %d"
                 % bare)

    open(output_path, "w", encoding="utf-8").write(src)
    print("opencode-ensemble patched: migration 9 added, team_create snapshot added, %d wake sites wrapped, helpers injected"
          % (len(SITES)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: opencode-ensemble.py <input-dist.js> <output.js>")
    patch(sys.argv[1], sys.argv[2])