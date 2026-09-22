# EFFICIENCY-PROPOSALS.md — Efficiency-lens proposals (record-only)

Proposals from the self-improvement checkpoint's **efficiency lens** land here.
This file is the counterpart to `GOTCHAS.md`/RUN LOGs, but is **proposal-only**:
an entry names a tool/skill/command/config idea that would collapse a genuinely
repeated pattern, cites the quantitative evidence (tool-call counts / token / cost
from the proposing session's own `opencode.db` row), and is **never built in the
session that wrote it**.

Rules:
- Append-only; one proposal per entry, newest last. Never build the proposed
  thing in-session (the efficiency lens only records).
- Entries go through `tools/self-improve-commit.sh` (allow-listed here) — the
  same mechanical evidence/append-only checks apply; evidence is the DB query
  output rather than a `file:line`.
- Proposals are ideas for a human (or a future session) to act on, not
  commitments. Anything ultimately adopted is built as normal task work, not via
  this log.
