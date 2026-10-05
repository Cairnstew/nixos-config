#!/usr/bin/env python3
"""
opencode-ensemble.py — build-time patch for version 0.19.0 (Cairnstew fork).

Patches the dist/index.js to fix the remaining wake-path defect sites.

Wake-path model hand-off: every wake promptAsync must carry the recipient's
model, or opencode answers the lead on its server default and silently undoes
the user's model selection the moment a teammate reports in (issue: "main agent
switches back to DeepSeek after a teammate responds").

The stored team.lead_model column is NULL on every team in practice — the
stock 0.19.0 dist ships no team_create writer for it — so the helper falls back
to reading the lead session's CURRENT model from OpenCode's own SQLite DB, the
same live read team_spawn already does. That makes the fix correct for new and
pre-existing teams alike, with no schema change.
"""
import sys

FAIL = "FORK-PATCH: expected anchor missing in %s: %r"

# Helper function to inject
HELPERS = """// ── FORK PATCH (wake-path fix) ────────────────────────────────────────────
// Vendored fork from https://github.com/Cairnstew/opencode-ensemble — see FORK.md.
function __ensembleWakeArgs(db, opts) {
  if (!db || !opts || !opts.sessionID) return opts;
  try {
    let agent = null;
    let model = null;
    const lead = db.query("SELECT lead_agent, lead_model FROM team WHERE lead_session_id = ? AND status = 'active'").get(opts.sessionID);
    if (lead) {
      agent = lead.lead_agent;
      model = lead.lead_model;
      // lead_model is NULL for every team whose team_create predates the
      // writer (and for all teams on a stock 0.19.0 dist, which has no such
      // writer at all). Falling through here left the wake a bare
      // promptAsync, and opencode answered it with its SERVER DEFAULT model —
      // silently dragging the lead off the model the user selected the moment
      // a teammate reported in. Read the lead session's CURRENT model straight
      // from OpenCode's own DB instead: the same live read team_spawn already
      // does via deps.leadModelReader. Never throws; undefined -> bare opts.
      if (!model) {
        try {
          if (typeof readSessionModel === "function") model = readSessionModel(opts.sessionID);
        } catch (err) { /* best effort */ }
      }
    } else {
      const m = db.query("SELECT agent, model FROM team_member WHERE session_id = ?").get(opts.sessionID);
      if (m) {
        agent = m.agent;
        model = m.model;
      }
    }
    if (!agent && !model) return opts;
    const out = Object.assign({}, opts);
    if (agent) out.agent = agent;
    if (model) {
      const slash = model.indexOf("/");
      if (slash > 0) out.model = { providerID: model.slice(0, slash), modelID: model.slice(slash + 1) };
    }
    return out;
  } catch (err) {
    return opts;
  }
}
// ── END FORK PATCH ─────────────────────────────────────────────────────────
"""

def patch(input_path: str, output_path: str) -> None:
    src = open(input_path, "r", encoding="utf-8").read()

    # Inject helpers after the first import block
    if "__ensembleWakeArgs" in src:
        sys.exit("FORK-PATCH: output already patched")
    
    # Find injection point - after init_process variable declaration (module scope)
    inject_marker = "var init_process = () => {};"
    inject_pos = src.find(inject_marker)
    if inject_pos == -1:
        sys.exit("FORK-PATCH: could not find injection point")
    inject_pos += len(inject_marker)
    
    src = src[:inject_pos] + "\n" + HELPERS + "\n" + src[inject_pos:]

    # Now wrap the wake sites that lack model handling
    # Site 1: notifyLead
    old1 = """client.session.promptAsync({
    sessionID: team.lead_session_id,
    parts: [{ type: "text", text: "[System: New team message from system]" }],
    synthetic: true
  })"""
    new1 = """client.session.promptAsync(__ensembleWakeArgs(db, {
    sessionID: team.lead_session_id,
    parts: [{ type: "text", text: "[System: New team message from system]" }],
    synthetic: true
  }))"""
    if old1 in src:
        src = src.replace(old1, new1, 1)
        print("  Wrapped: notifyLead")
    else:
        print("  SKIP (not found): notifyLead")

    # Site 2: team_message wake-lead
    old2 = """deps.client.session.promptAsync({
      sessionID: recipientSessionId,
      parts: [{ type: "text", text: `[System: New team message from ${senderName}]` }],
      synthetic: true
    })"""
    new2 = """deps.client.session.promptAsync(__ensembleWakeArgs(deps.db, {
      sessionID: recipientSessionId,
      parts: [{ type: "text", text: `[System: New team message from ${senderName}]` }],
      synthetic: true
    }))"""
    if old2 in src:
        src = src.replace(old2, new2, 1)
        print("  Wrapped: team_message wake-lead")
    else:
        print("  SKIP (not found): team_message wake-lead")

    # Site 3: team_broadcast delivery
    old3 = """deps.client.session.promptAsync({
      sessionID: recipient.sessionId,
      parts: [{ type: "text", text: `[Team broadcast from ${senderName}]: ${args.text}` }]
    })"""
    new3 = """deps.client.session.promptAsync(__ensembleWakeArgs(deps.db, {
      sessionID: recipient.sessionId,
      parts: [{ type: "text", text: `[Team broadcast from ${senderName}]: ${args.text}` }]
    }))"""
    if old3 in src:
        src = src.replace(old3, new3, 1)
        print("  Wrapped: team_broadcast delivery")
    else:
        print("  SKIP (not found): team_broadcast delivery")

    # Site 4: team-shutdown nudge
    old4 = """deps.client.session.promptAsync({
      sessionID: member.session_id,
      parts: [{ type: "text", text: shutdownText }]
    })"""
    new4 = """deps.client.session.promptAsync(__ensembleWakeArgs(deps.db, {
      sessionID: member.session_id,
      parts: [{ type: "text", text: shutdownText }]
    }))"""
    if old4 in src:
        src = src.replace(old4, new4, 1)
        print("  Wrapped: team-shutdown nudge")
    else:
        print("  SKIP (not found): team-shutdown nudge")

    # Site 5: pending-messages lead wake
    old5 = """client.session.promptAsync({
                sessionID,
                parts: [{ type: "text", text: `[System: ${pending.c} new team message(s) available]` }]
              })"""
    new5 = """client.session.promptAsync(__ensembleWakeArgs(db, {
                sessionID,
                parts: [{ type: "text", text: `[System: ${pending.c} new team message(s) available]` }]
              }))"""
    if old5 in src:
        src = src.replace(old5, new5, 1)
        print("  Wrapped: pending-messages lead wake")
    else:
        print("  SKIP (not found): pending-messages lead wake")

    # Post-conditions
    wake_count = src.count("__ensembleWakeArgs(")
    print(f"\nopencode-ensemble patched: {wake_count} wake sites wrapped (expected 6 = 5 wrapped + 1 definition)")
    
    open(output_path, "w", encoding="utf-8").write(src)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: opencode-ensemble.py <input-dist.js> <output.js>")
    patch(sys.argv[1], sys.argv[2])
