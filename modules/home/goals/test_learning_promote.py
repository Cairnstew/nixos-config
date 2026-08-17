#!/usr/bin/env python3
"""Standalone test for the learning promotion + review gate (agent self-
improvement pipeline).

Verifies the server-side behavior the full-auto `learning-promoter` agent and
the `triage-review` command rely on:

  * `learning_promote` is the ONLY path that changes `learnings.status`, and it
    strictly requires `acted_on_commit` for 'validated' (edit+promotion are one
    reviewed action).
  * `learning_promote` refuses non-proposed learnings.
  * `learning_review` only inserts `review_verdicts` rows and never touches
    `learnings.status` / `acted_on_commit`.
  * `learning_query` returns each learning's `review_verdicts`, and a fresh
    verdict row has `rederivation_method IS NULL` (the invariant that makes an
    un-re-derived verdict count as 'uncertain').
  * `learning_review` rejects invalid verdicts.

Stdlib only. Run:  python3 modules/home/goals/test_learning_promote.py
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


def make_learning(command="nix-refine", lesson="gate test", fix="patch x",
                  evidence="modules/home/goals/mcp_server.py:1026",
                  target_path="__unclassified__"):
    return mcp_server.learning_append(
        command=command, lesson=lesson, fix=fix, evidence=evidence,
        target_path=target_path,
    )["id"]


def test_validated_requires_commit_hash():
    fresh_db()
    lid = make_learning()
    try:
        mcp_server.learning_promote(lid, "validated")
        raise AssertionError("expected ValueError for validated without acted_on_commit")
    except ValueError as e:
        assert "acted_on_commit" in str(e), str(e)
    # still proposed — the failed promote changed nothing
    row = mcp_server.learning_query(status="proposed")
    assert any(r["id"] == lid for r in row), "learning must remain proposed after failed validate"
    print("PASS validated_requires_commit_hash")


def test_promote_sets_commit_and_status():
    conn = fresh_db()
    lid = make_learning()
    conn.execute("INSERT INTO review_verdicts (learning_id, reviewer_role, verdict, rederivation_method) VALUES (?, 'qa-verification', 'agree', 'read')", (lid,))
    conn.commit()
    got = mcp_server.learning_promote(lid, "validated", acted_on_commit="abc123")
    assert got["status"] == "validated", got
    assert got["acted_on_commit"] == "abc123", got
    assert mcp_server.learning_query(status="proposed") == [], "validated learning leaves proposed queue"
    print("PASS promote_sets_commit_and_status")


def test_reject_sets_status_rejected():
    conn = fresh_db()
    lid = make_learning(lesson="reject me")
    got = mcp_server.learning_promote(lid, "rejected")
    assert got["status"] == "rejected", got
    assert mcp_server.learning_query(status="proposed") == []
    print("PASS reject_sets_status_rejected")


def test_reject_requires_proposed():
    fresh_db()
    lid = make_learning(lesson="already handled")
    mcp_server.learning_promote(lid, "rejected")
    try:
        mcp_server.learning_promote(lid, "validated", acted_on_commit="x")
        raise AssertionError("expected ValueError for already-promoted learning")
    except ValueError as e:
        assert "proposed" in str(e), str(e)
    print("PASS reject_requires_proposed")


def test_review_inserts_row_and_keeps_status_proposed():
    conn = fresh_db()
    lid = make_learning(lesson="verdict rows")
    rv = mcp_server.learning_review(lid, "agree")
    assert rv["learning_id"] == lid and rv["verdict"] == "agree", rv
    assert rv["reviewer_role"] is None, "reviewer_role filled by capture plugin, not review()"
    assert rv["rederivation_method"] is None, "rederivation filled by capture plugin"
    # status untouched — review is observe-only
    rows = mcp_server.learning_query(status="proposed")
    assert any(r["id"] == lid for r in rows), "review must not change learning status"
    print("PASS review_inserts_row_and_keeps_status_proposed")


def test_review_rejects_bad_verdict():
    fresh_db()
    lid = make_learning(lesson="bad verdict")
    try:
        mcp_server.learning_review(lid, "maybe")
        raise AssertionError("expected ValueError for invalid verdict")
    except ValueError as e:
        assert "verdict" in str(e), str(e)
    print("PASS review_rejects_bad_verdict")


def test_query_returns_review_verdicts_with_null_rederivation():
    conn = fresh_db()
    lid = make_learning(lesson="query verdicts")
    mcp_server.learning_review(lid, "uncertain")
    rows = mcp_server.learning_query(status="proposed")
    me = next(r for r in rows if r["id"] == lid)
    assert "review_verdicts" in me, "learning_query must expose review_verdicts"
    assert len(me["review_verdicts"]) == 1, me
    assert me["review_verdicts"][0]["verdict"] == "uncertain"
    assert me["review_verdicts"][0]["rederivation_method"] is None, \
        "un-back-filled verdict must have rederivation_method IS NULL (counts as uncertain)"
    print("PASS query_returns_review_verdicts_with_null_rederivation")


if __name__ == "__main__":
    test_validated_requires_commit_hash()
    test_promote_sets_commit_and_status()
    test_reject_sets_status_rejected()
    test_reject_requires_proposed()
    test_review_inserts_row_and_keeps_status_proposed()
    test_review_rejects_bad_verdict()
    test_query_returns_review_verdicts_with_null_rederivation()
    print("ALL PASS")
