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


# ── Task 0: dedupe threshold validated against real RUN LOG pairs ─────────────
# Hand-labelled pairs extracted from the existing markdown RUN LOGs. Genuine
# duplicates: max-containment 0.357-0.625. Distinct-but-similar-sounding:
# 0.091-0.25. Threshold 0.30 separates the bands. See mcp_server._near_duplicate_lesson.

_REAL_PAIRS = [
    # Adversarial (Tier 0 nix-refine.md:846 vs :879): same surface topic (OOM +
    # builder waves), genuinely DIFFERENT claims. Must NOT dedupe.
    (
        "nix-refine OOM cgroup kill (2026-08-05): Running this command from the opencode web "
        "session on the server ended with blank browser sessions. systemd-oomd had killed the "
        "entire opencode-web-nix-config.service cgroup. Added an R-pre free -h memory check and "
        "builder spawning in waves on constrained hosts so a full parallel spawn can't spike the cgroup.",
        "nix-refine kernel-OOM from concurrent dry-activates (2026-08-06): The R-pre memory check "
        "used resting free -h and spawned 9-11 builders, each running a 5-host dry-activate loop. "
        "9+ concurrent evals hit the kernel global OOM killer, dropping the SSH session twice. "
        "Wave-of-2 + single-host-verify + a per-builder free -h guard had zero crashes after.",
        False,
    ),
    # Genuine near-duplicate: plan_approval lesson recorded in nix-doc-audit and
    # ported to nix-refine. Must dedupe.
    (
        "nix-doc-audit: Spawning B1-B3 with plan_approval true made each builder send its plan, "
        "end its run-cycle, and go idle forever. The lead's approve true response was stored but "
        "never delivered. All three builders stalled with zero edits until force-shutdown and re-spawn.",
        "nix-refine: plan_approval true never wakes builders after approval: a builder spawned "
        "with plan_approval sends its plan then ends its run-cycle; the lead's approve response is "
        "stored but never wakes it. The builder idles forever with zero edits.",
        True,
    ),
    # Genuine near-duplicate: team_merge silent-apply-nothing lesson, same wording
    # family in both commands. Must dedupe.
    (
        "nix-doc-audit: Builders that only stashed their changes (uncommitted) produced an empty "
        "team_merge result — the merge reported success but applied nothing, so the main repo kept "
        "the old content. The lead had to copy files from the worktree manually.",
        "nix-refine: team_merge silently applies nothing when a builder only stashed uncommitted "
        "its work — the lead must copy the worktree files into the main repo directly and verify.",
        True,
    ),
    # Distinct: worktree-fork-staleness vs dirty-file-refusal — both about dirty
    # trees but different mechanisms. Must NOT dedupe.
    (
        "nix-doc-audit: The main repo had 14 uncommitted md changes (the actual audit target). "
        "Builders git worktrees were created at committed HEAD, so their local copies were stale. "
        "Editing the stale copy would have made the merge clobber real work.",
        "nix-doc-audit: team_merge returned Cannot merge builder — you have local changes to the "
        "same files on ALL FOUR builder merges, because every target md was dirty in the main "
        "checkout. The preserved branch holds each file as dirty baseline plus intended edits.",
        False,
    ),
    # Distinct: researcher GitLab-mod research vs packwiz-docs research. Both web
    # research lessons, different subjects. Must NOT dedupe.
    (
        "researcher: researching Distant Horizons + Prominence II, the DH tracker is on GitLab not "
        "GitHub, and its wiki HTML pages are JS shells. The GitLab REST API returned clean JSON.",
        "researcher: researching packwiz configs, the site index pages all 404'd — only leaf pages "
        "serve, with the nav sidebar carrying the real URLs. The packwiz-installer GitHub README "
        "is a stub, so behavior had to be confirmed in source.",
        False,
    ),
    # Distinct: Modrinth /dependencies bloat vs nixos MCP version lag. Must NOT dedupe.
    (
        "researcher: webfetching api.modrinth.com project dependencies returned 1.5-2.3MB of full "
        "project objects per pack — truncated, and minified single-line JSON defeated the grep "
        "tool. The search endpoint's latest_version plus version/id gave compact per-version "
        "dependencies arrays.",
        "researcher: nixos MCP info returned stale versions while nix_versions history showed the "
        "real current releases. Package search also returned nothing for short ambiguous queries. "
        "Cross-check info against nix_versions for current-version claims.",
        False,
    ),
    # Distinct: RoadWeaver = "the trails mod" linking-whitelist vs RoadWeaver
    # water-crossing roads. Same mod, different lessons. Must NOT dedupe.
    (
        "skill-mc-mod-structures: there is no mod literally named trails; the roads/trails mod is "
        "RoadWeaver, and its structure-linking is NOT in its structure JSONs but in "
        "structurePrediction.structureWhitelist in config/roadweaver/roadweaver.json.",
        "skill-mc-mod-structures: user reported roads paving through ocean/water (RoadWeaver issue "
        "68) — water in land-tagged biomes treated as land; whitelist forced roads to ocean "
        "structures structory boat plus dragonsurvival sea. Seeding needed ignore-existing workaround.",
        False,
    ),
    # Genuine near-duplicate: RoadWeaver water-crossing roads, recorded in both
    # skill.md and skill-mc-mod-structures.md. Must dedupe.
    (
        "skill.md: user reported roads paving through ocean/water (RoadWeaver issue 68 — water in "
        "land-tagged biomes treated as land; plus whitelist forced roads to ocean structures "
        "structory:boat + dragonsurvival:*_sea). Seeding needed --ignore-existing workaround: "
        "remove the instance copy first.",
        "skill-mc-mod-structures: RoadWeaver issue 68 — roads pave through water in modded/untagged "
        "water biomes; check which whitelisted structure mods spawn structures in/near ocean so "
        "roads get forced across water.",
        True,
    ),
    # Genuine near-duplicate: --ignore-existing seeding gotcha in mc-install and
    # skill-mc-mod-config-set. Must dedupe.
    (
        "mc-install: shipping a changed mod default config (roadweaver whitelist) into an existing "
        "Prism instance was skipped: instance-sync seeds config with --ignore-existing, so "
        "mc-install reported up to date despite the stale file. Fix: delete the stale instance "
        "config file first, then force.",
        "skill-mc-mod-config-set: roadweaver.json seeding required --ignore-existing workaround: "
        "remove the instance copy before re-seeding so the changed default config reaches the instance.",
        True,
    ),
]


def test_dedupe_real_runlog_pairs():
    for i, (a, b, expect_dup) in enumerate(_REAL_PAIRS):
        got = mcp_server._near_duplicate_lesson(a, b)
        assert got is expect_dup, (
            f"pair {i}: expected {'DUP' if expect_dup else 'distinct'}, got {'DUP' if got else 'distinct'}\n"
            f"  A: {a[:100]}...\n  B: {b[:100]}..."
        )
    print(f"PASS dedupe_real_runlog_pairs ({len(_REAL_PAIRS)} pairs)")


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
    test_dedupe_real_runlog_pairs()
    print("ALL PASS")
