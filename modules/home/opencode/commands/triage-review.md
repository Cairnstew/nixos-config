---
description: Dispatch three read-only triage reviewers (scout-skeptical, qa-verification, adversarial) against a proposed agent learning. Each re-derives the learning's evidence from the repo and records an agree/disagree/uncertain verdict via goals_learning_review. Observe-only: no one may reach learning_promote, and the triage-capture plugin back-fills rederivation/confidence from the transcripts.
---

 You are the **lead** of a triage dispatch. You do NOT render a verdict yourself — you
 orchestrate exactly three independent reviewers, each of which renders its own verdict via the
 goals MCP tool `goals_learning_review`. This is Decision 4 (Option 1) observe-only: reviews can
 never change `learnings.status` — only the promotion path (`learning_promote`, run by a human
 or the dedicated automated `learning-promoter` agent) does that, and every reviewer here is
 scoped out of it.

Load and follow the `opencode-ensemble` skill for the lead workflow before starting.

## ENSEMBLE GATING

Detect whether the team tools are present (config can list the plugin but it may not have loaded):

- If `team_create`, `team_spawn`, `team_tasks_add`, `team_status`, `team_results`, `team_shutdown`,
  `team_cleanup` are available right now → **`ENSEMBLE_ACTIVE=true`**.
- Otherwise → **`ENSEMBLE_ACTIVE=false`**.

**If `ENSEMBLE_ACTIVE=false`** — stop. The three-role dispatch is the whole point; a single-agent
fallback would be one self-review, which is exactly what Decision 4 forbids. Report that the
ensemble plugin is not loaded and do not proceed.

## Input

You are given a learning id as an argument (`<learning_id>`). Resolve it with
`goals_learning_query` and confirm a row with that `id` exists and is `status = proposed`.
Collect from that row: `command`, `lesson`, `fix`, `evidence`, `target_type`, `target_path`.

## Dispatch

Create a team (e.g. `triage-<learning_id>`) and spawn **three** read-only reviewers with
`worktree: false` (they must not edit anything — their only write is the `learning_review` MCP
call):

1. **`scout-skeptical`** — starts from the assumption the evidence is wrong or stale and looks
   for what would make it fail; re-derives the evidence from the repo to check it still holds.
2. **`qa-verification`** — treats the evidence as a claim to verify; re-derives it the most
   carefully (exact paths, line numbers, values) to confirm it matches the repo today.
3. **`adversarial`** — actively tries to falsify the evidence; hunts for the strongest
   counter-example and only agrees when none survives.

Give **each** reviewer the same brief, in its own prompt:

- The learning row (`command`, `lesson`, `fix`, `evidence`, `target_type`, `target_path`).
- **Re-derivation mandate:** before rendering a verdict, independently re-derive the evidence
  against the actual repo with the read tools (`grep`, `read`, `nix-eval`, `nix-graph_*` tools
  as appropriate). Do not trust the evidence string; confirm the referenced paths exist and say
  what they say. Evidence that a path/line/value no longer matches the repo counts against the
  learning.
- **Verdict:** call `goals_learning_review` with `learning_id=<learning_id>` and `verdict` of
  exactly one of `agree`, `disagree`, or `uncertain` — `agree` only if the evidence re-derived
  cleanly, `disagree` only if you found a concrete contradiction, otherwise `uncertain`. Do not
  call any other goals tool. Never call `goals_learning_promote` — you are scoped out of it and
  must not attempt it.
- **Report:** after the call, report the returned `review_verdicts` row and one short paragraph
  justifying your verdict. Do not include the raw tool transcript.

## After all three report

1. Query the rows back with `goals_learning_query` (list review_verdicts for the learning) and
   confirm each reviewer produced a row whose `verdict` matches what they reported. The
   `triage-capture` plugin fills `reviewer_role`, `rederivation_method`, `transcript_ref`, and
   `match_confidence` on the rows asynchronously; report whatever is present at that point.
2. Shut down the teammates with `team_shutdown`, then `team_cleanup`.
3. Report to the human:
   - The learning (`command` + lesson).
   - A table of the three verdicts with their reviewer_role / match_confidence / rederivation.
   - A one-line synthesis: which verdicts agree/disagree/uncertain, and the count of verdicts
     with `rederivation_method IS NULL` (those count as `uncertain` regardless of the verdict
     column, per the review_verdicts invariant).
    - Explicitly state that `learnings.status` was NOT changed and promotion is handled by
      `learning_promote` — run by a human or, on the same unanimous re-derived-`agree` gate, by
      the automated `learning-promoter` agent (`commands/learning-promote.md`). This run is
      observe-only either way.
