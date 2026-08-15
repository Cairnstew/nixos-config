#!/usr/bin/env python3
"""Standalone test for learning_append (agent self-improvement pilot).

The goals module tests only L0 config assertions in tests.nix (nothing tests
the MCP tool logic), so this is the equivalent: import the module's own
functions, run them against a throwaway SQLite DB, assert the Decision 4 gate
(always 'proposed') and the evidence/dedupe rules. Stdlib only.

Run:  python3 modules/home/goals/test_learning_append.py
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import mcp_server  # noqa: E402


def fresh_db():
    tmp = tempfile.mkdtemp(prefix="goals-test-")
    db_path = os.path.join(tmp, "test.db")
    schema_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema.sql")
    conn = mcp_server.init_db(db_path, schema_path=schema_path)
    mcp_server.conn = conn
    return conn


def test_reject_missing_evidence():
    conn = fresh_db()
    mcp_server.conn = conn
    try:
        mcp_server.learning_append(command="nix-refine", lesson="x", fix="y", evidence="")
        raise AssertionError("expected ValueError for empty evidence")
    except ValueError as e:
        assert "evidence" in str(e).lower(), str(e)
    print("PASS reject_missing_evidence")


def test_reject_placeholder_evidence():
    conn = fresh_db()
    mcp_server.conn = conn
    for bad in ("placeholder", "TBD", "none yet", "placeholder-scan"):
        try:
            mcp_server.learning_append(command="nix-refine", lesson="x", fix="y", evidence=bad)
            raise AssertionError(f"expected ValueError for evidence={bad!r}")
        except ValueError:
            pass
    print("PASS reject_placeholder_evidence")


def test_status_always_proposed():
    conn = fresh_db()
    mcp_server.conn = conn
    row = mcp_server.learning_append(
        command="nix-refine",
        lesson="dedupe works",
        fix="check before insert",
        evidence="modules/home/opencode/commands/nix-refine.md:897",
    )
    assert row["status"] == "proposed", row
    assert row["deduped"] is False, row
    count = conn.execute("SELECT COUNT(*) FROM learnings").fetchone()[0]
    assert count == 1, count
    print("PASS status_always_proposed")


def test_dedupe_near_duplicate_lesson():
    conn = fresh_db()
    mcp_server.conn = conn
    mcp_server.learning_append(
        command="nix-refine",
        lesson="team_merge silently applies nothing on uncommitted builder work",
        fix="cp worktree files into main repo",
        evidence="modules/home/opencode/commands/nix-doc-audit.md:925",
    )
    # Near-duplicate wording of the same lesson.
    row2 = mcp_server.learning_append(
        command="nix-refine",
        lesson="team_merge silently applies nothing when builder work is uncommitted",
        fix="cp worktree files into main repo",
        evidence="modules/home/opencode/commands/nix-refine.md:795",
    )
    assert row2["deduped"] is True, row2
    assert row2["status"] == "proposed", row2
    count = conn.execute("SELECT COUNT(*) FROM learnings").fetchone()[0]
    assert count == 1, f"expected dedupe, got {count} rows"
    print("PASS dedupe_near_duplicate_lesson")


def test_distinct_lessons_not_deduped():
    conn = fresh_db()
    mcp_server.conn = conn
    mcp_server.learning_append(
        command="nix-refine",
        lesson="OOM waves of two prevent session crashes",
        fix="spawn builders in waves of 2",
        evidence="modules/home/opencode/commands/nix-refine.md:879",
    )
    mcp_server.learning_append(
        command="nix-refine",
        lesson="plan_approval true never wakes builders",
        fix="never use plan_approval",
        evidence="modules/home/opencode/commands/nix-refine.md:868",
    )
    count = conn.execute("SELECT COUNT(*) FROM learnings").fetchone()[0]
    assert count == 2, f"expected 2 distinct learnings, got {count}"
    print("PASS distinct_lessons_not_deduped")


def test_promote_validated_requires_commit():
    conn = fresh_db()
    mcp_server.conn = conn
    row = mcp_server.learning_append(
        command="nix-refine",
        lesson="gate lesson",
        fix="apply gated",
        evidence="modules/home/opencode/commands/nix-refine.md:897",
    )
    try:
        mcp_server.learning_promote(row["id"], "validated")
        raise AssertionError("expected ValueError for validated without acted_on_commit")
    except ValueError as e:
        assert "acted_on_commit" in str(e), str(e)
    # Still proposed after the failed promote.
    after = mcp_server.learning_query(command="nix-refine")
    assert after[0]["status"] == "proposed", after
    print("PASS promote_validated_requires_commit")


def test_promote_validated_sets_commit():
    conn = fresh_db()
    mcp_server.conn = conn
    row = mcp_server.learning_append(
        command="nix-refine",
        lesson="validate me",
        fix="land the edit",
        evidence="modules/home/opencode/commands/nix-refine.md:879",
    )
    promoted = mcp_server.learning_promote(row["id"], "validated", acted_on_commit="abc1234")
    assert promoted["status"] == "validated", promoted
    assert promoted["acted_on_commit"] == "abc1234", promoted
    print("PASS promote_validated_sets_commit")


def test_promote_rejected():
    conn = fresh_db()
    mcp_server.conn = conn
    row = mcp_server.learning_append(
        command="nix-refine",
        lesson="reject me",
        fix="n/a",
        evidence="modules/home/opencode/commands/nix-refine.md:917",
    )
    rejected = mcp_server.learning_promote(row["id"], "rejected")
    assert rejected["status"] == "rejected", rejected
    print("PASS promote_rejected")


def test_query_filters():
    conn = fresh_db()
    mcp_server.conn = conn
    mcp_server.learning_append(
        command="nix-refine",
        lesson="query me one",
        fix="x",
        evidence="modules/home/opencode/commands/nix-refine.md:846",
    )
    mcp_server.learning_append(
        command="nix-doc-audit",
        lesson="query me two",
        fix="y",
        evidence="modules/home/opencode/commands/nix-doc-audit.md:908",
    )
    refine = mcp_server.learning_query(command="nix-refine")
    assert len(refine) == 1 and refine[0]["command"] == "nix-refine", refine
    all_proposed = mcp_server.learning_query(status="proposed")
    assert len(all_proposed) == 2, all_proposed
    print("PASS query_filters")


if __name__ == "__main__":
    test_reject_missing_evidence()
    test_reject_placeholder_evidence()
    test_status_always_proposed()
    test_dedupe_near_duplicate_lesson()
    test_distinct_lessons_not_deduped()
    test_promote_validated_requires_commit()
    test_promote_validated_sets_commit()
    test_promote_rejected()
    test_query_filters()
    print("ALL PASS")
