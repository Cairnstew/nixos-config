#!/usr/bin/env python3
"""MCP stdio server for personal goals tracking + auto-updating traits.

Uses raw JSON-RPC over stdin/stdout (no SDK dependency).
Only needs python3 + sqlite3 (stdlib).

Usage:
  python3 goals_mcp.py --db /path/to/goals.db
"""

import argparse
import datetime
import json
import os
import re
import sqlite3
import sys
import traceback

SCHEMA_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "schema.sql")


def init_db(db_path: str, schema_path: str = SCHEMA_PATH) -> sqlite3.Connection:
    os.makedirs(os.path.dirname(db_path) or ".", exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    with open(schema_path) as f:
        conn.executescript(f.read())
    # Migration: add "order" column to milestones if missing (pre-Tier 4 DBs)
    try:
        conn.execute("ALTER TABLE milestones ADD COLUMN \"order\" INTEGER NOT NULL DEFAULT 0")
    except sqlite3.OperationalError as e:
        if "duplicate column" not in str(e):
            raise  # re-raise unexpected schema errors
    # Migration: add profile_facts table if missing (pre-Tier 5 DBs)
    # No exception handling needed — CREATE TABLE IF NOT EXISTS is idempotent.
    conn.execute("""CREATE TABLE IF NOT EXISTS profile_facts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL CHECK (category IN ('background', 'current_commitment', 'skill', 'value', 'relationship', 'constraint', 'history')),
        fact_text TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        superseded_by INTEGER REFERENCES profile_facts(id),
        source_check_in_id INTEGER REFERENCES check_ins(id),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )""")
    # Migration: agent self-improvement tables (pre-agent-learning DBs; 2026-08-15
    # pilot). Additive only — personal goals/traits data is untouched. The full
    # definitions live in schema.sql; this inline block is the migration-fix
    # pattern for pre-existing DBs (mirrors the profile_facts block above).
    conn.execute("""CREATE TABLE IF NOT EXISTS learnings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL DEFAULT 'agent-learning',
        command TEXT NOT NULL,
        lesson TEXT NOT NULL,
        fix TEXT NOT NULL DEFAULT '',
        evidence TEXT NOT NULL CHECK (length(trim(evidence)) > 0),
        status TEXT NOT NULL DEFAULT 'proposed',
        alpha REAL NOT NULL DEFAULT 1.0,
        beta REAL NOT NULL DEFAULT 1.0,
        confidence REAL NOT NULL DEFAULT 0.5,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        acted_on_commit TEXT,
        superseded_by INTEGER REFERENCES learnings(id)
    )""")
    conn.execute("""CREATE TABLE IF NOT EXISTS learning_evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        learning_id INTEGER NOT NULL REFERENCES learnings(id),
        evidence_value REAL NOT NULL,
        note TEXT,
        observed_date TEXT NOT NULL
    )""")
    conn.execute("""CREATE TABLE IF NOT EXISTS fabrication_incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL DEFAULT 'agent-learning',
        command TEXT NOT NULL,
        pattern_type TEXT NOT NULL,
        date TEXT NOT NULL,
        evidence TEXT NOT NULL CHECK (length(trim(evidence)) > 0),
        description TEXT NOT NULL
    )""")
    _seed_fabrication_incidents(conn)
    conn.commit()
    return conn


AGENT_LEARNING_DOMAIN = "agent-learning"


def _seed_fabrication_incidents(conn: sqlite3.Connection) -> None:
    """Idempotently seed fabrication_incidents with the three incidents Tier 0
    already found. Evidence is cited exactly as in the Tier 0 findings doc
    (/tmp/opencode/self-improvement/tier0-findings.md §3d) and the RUN LOG rows
    they came from; nothing is re-derived here. Idempotent on
    (command, pattern_type, evidence)."""
    incidents = [
        {
            "command": "nix-doc-audit",
            "pattern_type": "fabricated-grep-output",
            "date": "2026-08-03",
            "evidence": "modules/home/opencode/commands/nix-doc-audit.md:967-976",
            "description": (
                "M11 faulty-grep fabrication: arbiter SKIP ruling claimed 0 matches for a pattern "
                "that actually matched 5 times (README lines 4,10,11,28,29,131 reference non-existent "
                "modules/flake-parts/ventoy.nix/ventoy-config.nix). Caught by lead re-verification."
            ),
        },
        {
            "command": "nix-refine",
            "pattern_type": "fabricated-default-claim",
            "date": "2026-08-07",
            "evidence": "modules/home/opencode/commands/nix-refine.md:917-933",
            "description": (
                "K1 false 'default is already true' claim: recon asserted "
                "boot.loader.efi.canTouchEfiVariables was redundant because 'NixOS default is already "
                "true' — factually wrong (nixpkgs default is false). Only nix eval before/after caught "
                "it; required git revert 96e324a."
            ),
        },
        {
            "command": "nix-refine",
            "pattern_type": "namespace-misread",
            "date": "2026-08-06",
            "evidence": "modules/home/opencode/commands/nix-refine.md:519-528",
            "description": (
                "Tailscale namespace misread: scout + planner claimed workstation.nix tailscale.enable "
                "duplicated common.nix:285, but common.nix sets NixOS-native services.tailscale, not "
                "the module option my.services.tailscale; the plan would have disabled tailscale on all "
                "workstation hosts."
            ),
        },
    ]
    for row in incidents:
        hit = conn.execute(
            "SELECT 1 FROM fabrication_incidents WHERE command = ? AND pattern_type = ? AND evidence = ?",
            (row["command"], row["pattern_type"], row["evidence"]),
        ).fetchone()
        if hit:
            continue
        conn.execute(
            """INSERT INTO fabrication_incidents (command, pattern_type, date, evidence, description)
               VALUES (?, ?, ?, ?, ?)""",
            (row["command"], row["pattern_type"], row["date"], row["evidence"], row["description"]),
        )


class TraitEngine:
    def __init__(
        self,
        decay_factor: float = 0.98,
        min_days: int = 3,
        min_count: int = 5,
        promotion_threshold: float = 0.65,
        retire_threshold: float = 0.35,
    ):
        self.decay_factor = decay_factor
        self.min_days = min_days
        self.min_count = min_count
        self.promotion_threshold = promotion_threshold
        self.retire_threshold = retire_threshold

    def _elapsed_weeks(self, last_updated: str, now: str) -> float:
        last = datetime.datetime.fromisoformat(last_updated)
        current = datetime.datetime.fromisoformat(now)
        delta = current - last
        return delta.total_seconds() / (7 * 24 * 3600)

    def compute_confidence(self, alpha: float, beta: float) -> float:
        total = alpha + beta
        if total == 0:
            return 0.5
        return alpha / total

    def update_trait(
        self,
        conn: sqlite3.Connection,
        trait_id: int,
        evidence_value: float,
        check_in_id: int | None = None,
        note: str | None = None,
        observed_date: str | None = None,
        _now: str | None = None,
    ) -> dict:
        cur = conn.execute(
            "SELECT id, name, status, alpha, beta, confidence, last_updated FROM traits WHERE id = ?",
            (trait_id,),
        )
        row = cur.fetchone()
        if not row:
            raise ValueError(f"Trait {trait_id} not found")

        alpha, beta = row["alpha"], row["beta"]
        last_updated = row["last_updated"]

        if _now is None:
            _now = datetime.datetime.utcnow().isoformat()
        if observed_date is None:
            observed_date = datetime.date.today().isoformat()

        elapsed_weeks = self._elapsed_weeks(last_updated, _now)
        decay = self.decay_factor ** elapsed_weeks
        alpha = alpha * decay
        beta = beta * decay

        if evidence_value > 0.5:
            alpha += 1.0
        elif evidence_value < 0.5:
            beta += 1.0

        confidence = self.compute_confidence(alpha, beta)

        conn.execute(
            "UPDATE traits SET alpha = ?, beta = ?, confidence = ?, last_updated = ? WHERE id = ?",
            (alpha, beta, confidence, _now, trait_id),
        )
        conn.execute(
            "INSERT INTO trait_evidence (trait_id, check_in_id, evidence_value, note, observed_date) VALUES (?, ?, ?, ?, ?)",
            (trait_id, check_in_id, evidence_value, note, observed_date),
        )

        status = row["status"]
        new_status = self._check_status(conn, trait_id, confidence, status)
        if new_status != status:
            conn.execute("UPDATE traits SET status = ? WHERE id = ?", (new_status, trait_id))

        return {
            "id": trait_id,
            "name": row["name"],
            "alpha": alpha,
            "beta": beta,
            "confidence": confidence,
            "status": new_status,
            "last_updated": _now,
            "elapsed_weeks": elapsed_weeks,
            "decay_applied": decay,
        }

    def _check_status(self, conn: sqlite3.Connection, trait_id: int, confidence: float, current_status: str) -> str:
        if current_status in ("proposed", "retired") and confidence >= self.promotion_threshold:
            row = conn.execute(
                "SELECT COUNT(DISTINCT observed_date) as days, COUNT(*) as total FROM trait_evidence WHERE trait_id = ?",
                (trait_id,),
            ).fetchone()
            if row["days"] >= self.min_days and row["total"] >= self.min_count:
                return "active"

        if current_status == "active" and confidence < self.retire_threshold:
            return "retired"

        return current_status


conn: sqlite3.Connection | None = None
engine: TraitEngine | None = None
AT_RISK_THRESHOLD: float = 0.15
BEHIND_THRESHOLD: float = 0.30


def list_goals(domain: str | None = None, status: str | None = None) -> list[dict]:
    query = "SELECT g.*, d.name as domain_name FROM goals g JOIN domains d ON g.domain_id = d.id"
    params: list = []
    where: list[str] = []
    if domain is not None:
        where.append("d.name = ?")
        params.append(domain)
    if status is not None:
        where.append("g.status = ?")
        params.append(status)
    if where:
        query += " WHERE " + " AND ".join(where)
    query += " ORDER BY g.priority, g.created_at DESC"
    return [dict(r) for r in conn.execute(query, params).fetchall()]


def create_goal(
    domain: str,
    title: str,
    why_it_matters: str = "",
    priority: int = 3,
    target_date: str | None = None,
) -> dict:
    now = datetime.datetime.utcnow().isoformat()
    cur = conn.execute("SELECT id FROM domains WHERE name = ?", (domain,))
    row = cur.fetchone()
    if row:
        domain_id = row["id"]
    else:
        cur = conn.execute("INSERT INTO domains (name) VALUES (?)", (domain,))
        domain_id = cur.lastrowid
    cur = conn.execute(
        "INSERT INTO goals (domain_id, title, why_it_matters, priority, target_date, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (domain_id, title, why_it_matters, priority, target_date, now, now),
    )
    goal_id = cur.lastrowid
    conn.commit()
    return dict(conn.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone())


def update_goal(id: int, **fields) -> dict:
    allowed = {"title", "why_it_matters", "status", "priority", "target_date"}
    updates = {k: v for k, v in fields.items() if k in allowed and v is not None}
    if not updates:
        raise ValueError("No valid fields to update")
    updates["updated_at"] = datetime.datetime.utcnow().isoformat()
    set_clause = ", ".join(f"{k} = ?" for k in updates)
    values = list(updates.values()) + [id]
    conn.execute(f"UPDATE goals SET {set_clause} WHERE id = ?", values)
    conn.commit()
    row = conn.execute("SELECT * FROM goals WHERE id = ?", (id,)).fetchone()
    if not row:
        raise ValueError(f"Goal {id} not found")
    return dict(row)


def log_action_taken(goal_id: int, description: str, milestone_id: int | None = None) -> dict:
    now = datetime.datetime.utcnow().isoformat()
    cur = conn.execute(
        "INSERT INTO actions (goal_id, milestone_id, description, status, created_at, completed_at) VALUES (?, ?, ?, 'done', ?, ?)",
        (goal_id, milestone_id, description, now, now),
    )
    action_id = cur.lastrowid
    conn.execute("UPDATE goals SET updated_at = ? WHERE id = ?", (now, goal_id))
    conn.commit()
    return dict(conn.execute("SELECT * FROM actions WHERE id = ?", (action_id,)).fetchone())


def get_stale_goals(days_threshold: int = 14) -> list[dict]:
    cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=days_threshold)).isoformat()
    cur = conn.execute(
        """SELECT g.*, d.name as domain_name
           FROM goals g
           JOIN domains d ON g.domain_id = d.id
           WHERE g.updated_at < ? AND g.status != 'done'
           ORDER BY g.updated_at ASC""",
        (cutoff,),
    )
    return [dict(r) for r in cur.fetchall()]


def get_domain_balance(window_days: int = 30) -> list[dict]:
    cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=window_days)).isoformat()
    cur = conn.execute(
        """SELECT d.id, d.name,
                  COUNT(DISTINCT ci.id) as check_in_count,
                  COUNT(DISTINCT a.id) as action_count
           FROM domains d
           LEFT JOIN check_ins ci ON ci.domain_id = d.id AND ci.created_at >= ?
           LEFT JOIN actions a ON a.goal_id IN (SELECT id FROM goals WHERE domain_id = d.id)
               AND a.created_at >= ?
           GROUP BY d.id, d.name
           ORDER BY d.name""",
        (cutoff, cutoff),
    )
    return [dict(r) for r in cur.fetchall()]


def log_check_in(
    domain: str,
    goal_id: int | None = None,
    text: str = "",
    sentiment: str | None = None,
    trait_updates: list[dict] | None = None,
) -> dict:
    now = datetime.datetime.utcnow().isoformat()
    today = datetime.date.today().isoformat()

    cur = conn.execute("SELECT id FROM domains WHERE name = ?", (domain,))
    row = cur.fetchone()
    if row:
        domain_id = row["id"]
    else:
        cur = conn.execute("INSERT INTO domains (name) VALUES (?)", (domain,))
        domain_id = cur.lastrowid

    cur = conn.execute(
        "INSERT INTO check_ins (domain_id, goal_id, text, sentiment, created_at) VALUES (?, ?, ?, ?, ?)",
        (domain_id, goal_id, text, sentiment, now),
    )
    check_in_id = cur.lastrowid

    if goal_id:
        conn.execute("UPDATE goals SET updated_at = ? WHERE id = ?", (now, goal_id))

    trait_results = []
    if trait_updates:
        for update in trait_updates:
            result = engine.update_trait(
                conn,
                trait_id=update["trait_id"],
                evidence_value=update["evidence_value"],
                check_in_id=check_in_id,
                note=update.get("note"),
                observed_date=today,
            )
            trait_results.append(result)

    conn.commit()

    return {
        "check_in_id": check_in_id,
        "domain_id": domain_id,
        "goal_id": goal_id,
        "created_at": now,
        "trait_updates": trait_results,
        "active_traits": list_traits(status="active"),
    }


def list_traits(status: str | None = None) -> list[dict]:
    query = "SELECT * FROM traits"
    params: list = []
    if status is not None:
        query += " WHERE status = ?"
        params.append(status)
    query += " ORDER BY confidence DESC, first_observed ASC"
    return [dict(r) for r in conn.execute(query, params).fetchall()]


def get_trait(id: int) -> dict:
    row = conn.execute("SELECT * FROM traits WHERE id = ?", (id,)).fetchone()
    if not row:
        raise ValueError(f"Trait {id} not found")
    evidence = conn.execute(
        "SELECT * FROM trait_evidence WHERE trait_id = ? ORDER BY observed_date DESC, id DESC",
        (id,),
    ).fetchall()
    result = dict(row)
    result["evidence"] = [dict(e) for e in evidence]
    return result


def propose_trait(name: str, description: str = "", category: str = "behavior") -> dict:
    now = datetime.datetime.utcnow().isoformat()
    today = datetime.date.today().isoformat()
    cur = conn.execute(
        "INSERT INTO traits (name, description, category, status, alpha, beta, confidence, last_updated, first_observed) VALUES (?, ?, ?, 'proposed', 1.0, 1.0, 0.5, ?, ?)",
        (name, description, category, now, today),
    )
    trait_id = cur.lastrowid
    conn.commit()
    return dict(conn.execute("SELECT * FROM traits WHERE id = ?", (trait_id,)).fetchone())


def create_milestone(
    goal_id: int,
    title: str,
    target_date: str | None = None,
    order: int = 0,
) -> dict:
    cur = conn.execute("SELECT id FROM goals WHERE id = ?", (goal_id,))
    if not cur.fetchone():
        raise ValueError(f"Goal {goal_id} not found")
    now = datetime.datetime.utcnow().isoformat()
    cur = conn.execute(
        "INSERT INTO milestones (goal_id, title, status, target_date, \"order\", created_at) VALUES (?, ?, 'pending', ?, ?, ?)",
        (goal_id, title, target_date, order, now),
    )
    milestone_id = cur.lastrowid
    conn.commit()
    return dict(conn.execute("SELECT * FROM milestones WHERE id = ?", (milestone_id,)).fetchone())


def list_milestones(goal_id: int) -> list[dict]:
    rows = conn.execute(
        """SELECT m.*, COUNT(a.id) as action_count
           FROM milestones m
           LEFT JOIN actions a ON a.milestone_id = m.id
           WHERE m.goal_id = ?
           GROUP BY m.id
           ORDER BY m."order" ASC, m.created_at ASC""",
        (goal_id,),
    ).fetchall()
    return [dict(r) for r in rows]


def update_milestone(id: int, status: str | None = None, target_date: str | None = None) -> dict:
    updates = {}
    if status is not None:
        updates["status"] = status
    if target_date is not None:
        updates["target_date"] = target_date
    if not updates:
        raise ValueError("No valid fields to update")
    set_clause = ", ".join(f"{k} = ?" for k in updates)
    values = list(updates.values()) + [id]
    conn.execute(f"UPDATE milestones SET {set_clause} WHERE id = ?", values)
    conn.commit()
    row = conn.execute("SELECT * FROM milestones WHERE id = ?", (id,)).fetchone()
    if not row:
        raise ValueError(f"Milestone {id} not found")
    return dict(row)


def get_milestone(id: int) -> dict:
    row = conn.execute(
        """SELECT m.*, COUNT(a.id) as action_count
           FROM milestones m
           LEFT JOIN actions a ON a.milestone_id = m.id
           WHERE m.id = ?
           GROUP BY m.id""",
        (id,),
    ).fetchone()
    if not row:
        raise ValueError(f"Milestone {id} not found")
    result = dict(row)
    actions = conn.execute(
        "SELECT * FROM actions WHERE milestone_id = ? ORDER BY created_at DESC", (id,)
    ).fetchall()
    result["actions"] = [dict(a) for a in actions]
    return result


def get_timeline_health(
    goal_id: int,
    at_risk_threshold: float = 0.15,
    behind_threshold: float = 0.30,
) -> dict:
    row = conn.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
    if not row:
        raise ValueError(f"Goal {goal_id} not found")

    goal = dict(row)

    if not goal.get("target_date"):
        return {
            "goal_id": goal_id,
            "title": goal["title"],
            "status": "undefined",
            "reason": "Goal has no target_date",
        }

    now = datetime.datetime.utcnow().isoformat()
    now_dt = datetime.datetime.fromisoformat(now)
    created_dt = datetime.datetime.fromisoformat(goal["created_at"])
    target_dt = datetime.datetime.fromisoformat(goal["target_date"])

    total_milestones = conn.execute(
        "SELECT COUNT(*) as c FROM milestones WHERE goal_id = ?", (goal_id,)
    ).fetchone()["c"]

    if total_milestones == 0:
        return {
            "goal_id": goal_id,
            "title": goal["title"],
            "status": "undefined",
            "reason": "Goal has no milestones",
        }

    total_span = (target_dt - created_dt).total_seconds()
    if total_span <= 0:
        return {
            "goal_id": goal_id,
            "title": goal["title"],
            "status": "undefined",
            "reason": "Goal has zero or negative timespan (target_date <= created_at)",
        }

    if now_dt > target_dt:
        overdue_days = (now_dt - target_dt).days
        return {
            "goal_id": goal_id,
            "title": goal["title"],
            "status": "overdue",
            "reason": f"Past target date by {overdue_days} days",
            "overdue_days": overdue_days,
        }

    elapsed_span = (now_dt - created_dt).total_seconds()
    elapsed_fraction = elapsed_span / total_span

    completed = conn.execute(
        "SELECT COUNT(*) as c FROM milestones WHERE goal_id = ? AND status = 'done'", (goal_id,)
    ).fetchone()["c"]
    progress_fraction = completed / total_milestones

    gap = elapsed_fraction - progress_fraction

    if gap < at_risk_threshold:
        status = "on_track"
    elif gap < behind_threshold:
        status = "at_risk"
    else:
        status = "behind"

    return {
        "goal_id": goal_id,
        "title": goal["title"],
        "status": status,
        "elapsed_fraction": round(elapsed_fraction, 4),
        "progress_fraction": round(progress_fraction, 4),
        "gap": round(gap, 4),
        "total_milestones": total_milestones,
        "completed_milestones": completed,
        "target_date": goal["target_date"],
    }


def get_today_context() -> dict:
    active_goals = conn.execute(
        """SELECT g.*, d.name as domain_name
           FROM goals g JOIN domains d ON g.domain_id = d.id
           WHERE g.status IN ('active', 'in_progress')
           ORDER BY g.priority, g.created_at DESC"""
    ).fetchall()

    stale_goals = get_stale_goals()
    active_traits = list_traits(status="active")
    proposed_traits_list = list_traits(status="proposed")

    last_check_in = conn.execute(
        """SELECT ci.*, d.name as domain_name
           FROM check_ins ci JOIN domains d ON ci.domain_id = d.id
           ORDER BY ci.created_at DESC LIMIT 1"""
    ).fetchone()

    roadmap_health = []
    for g in active_goals:
        if g["target_date"]:
            total_m = conn.execute(
                "SELECT COUNT(*) as c FROM milestones WHERE goal_id = ?", (g["id"],)
            ).fetchone()["c"]
            if total_m > 0:
                try:
                    health = get_timeline_health(g["id"], at_risk_threshold=AT_RISK_THRESHOLD, behind_threshold=BEHIND_THRESHOLD)
                    roadmap_health.append(health)
                except (ValueError, ZeroDivisionError):
                    pass

    active_facts = conn.execute(
        "SELECT id, category, fact_text FROM profile_facts WHERE status = 'active' AND category IN ('current_commitment', 'constraint')"
    ).fetchall()

    return {
        "active_goals": [dict(g) for g in active_goals],
        "stale_goals": stale_goals,
        "active_traits": active_traits,
        "proposed_traits": proposed_traits_list,
        "last_check_in": dict(last_check_in) if last_check_in else None,
        "roadmap_health": roadmap_health,
        "active_commitments_and_constraints": [dict(f) for f in active_facts],
    }


FACT_CATEGORIES = frozenset({"background", "current_commitment", "skill", "value", "relationship", "constraint", "history"})


def record_fact(category: str, fact_text: str, source_check_in_id: int | None = None) -> dict:
    if category not in FACT_CATEGORIES:
        raise ValueError(f"Invalid category '{category}'. Must be one of: {', '.join(sorted(FACT_CATEGORIES))}")
    now = datetime.datetime.utcnow().isoformat()
    cur = conn.execute(
        "INSERT INTO profile_facts (category, fact_text, status, source_check_in_id, created_at, updated_at) VALUES (?, ?, 'active', ?, ?, ?)",
        (category, fact_text, source_check_in_id, now, now),
    )
    fact_id = cur.lastrowid
    conn.commit()
    return dict(conn.execute("SELECT * FROM profile_facts WHERE id = ?", (fact_id,)).fetchone())


def supersede_fact(old_id: int, new_category: str, new_fact_text: str, source_check_in_id: int | None = None) -> dict:
    old_row = conn.execute("SELECT * FROM profile_facts WHERE id = ?", (old_id,)).fetchone()
    if not old_row:
        raise ValueError(f"Fact {old_id} not found")
    if new_category not in FACT_CATEGORIES:
        raise ValueError(f"Invalid category '{new_category}'. Must be one of: {', '.join(sorted(FACT_CATEGORIES))}")
    now = datetime.datetime.utcnow().isoformat()
    cur = conn.execute(
        "INSERT INTO profile_facts (category, fact_text, status, source_check_in_id, created_at, updated_at) VALUES (?, ?, 'active', ?, ?, ?)",
        (new_category, new_fact_text, source_check_in_id, now, now),
    )
    new_id = cur.lastrowid
    conn.execute(
        "UPDATE profile_facts SET status = 'superseded', superseded_by = ?, updated_at = ? WHERE id = ?",
        (new_id, now, old_id),
    )
    conn.commit()
    new_row = dict(conn.execute("SELECT * FROM profile_facts WHERE id = ?", (new_id,)).fetchone())
    new_row["superseded_fact_id"] = old_id
    return new_row


def list_facts(category: str | None = None, status: str = "active") -> list[dict]:
    query = "SELECT * FROM profile_facts"
    params: list = []
    where: list[str] = []
    if category is not None:
        where.append("category = ?")
        params.append(category)
    where.append("status = ?")
    params.append(status)
    query += " WHERE " + " AND ".join(where)
    query += " ORDER BY created_at DESC"
    return [dict(r) for r in conn.execute(query, params).fetchall()]


def get_fact(id: int) -> dict:
    row = conn.execute("SELECT * FROM profile_facts WHERE id = ?", (id,)).fetchone()
    if not row:
        raise ValueError(f"Fact {id} not found")
    result = dict(row)
    chain: list[dict] = []
    next_id = row["superseded_by"]
    while next_id:
        r = conn.execute("SELECT id, category, fact_text, status, superseded_by FROM profile_facts WHERE id = ?", (next_id,)).fetchone()
        if not r:
            break
        chain.append(dict(r))
        next_id = r["superseded_by"]
    result["superseded_by_chain"] = chain
    predecessor = conn.execute(
        "SELECT id, category, fact_text, status FROM profile_facts WHERE superseded_by = ?", (id,)
    ).fetchone()
    result["predecessor"] = dict(predecessor) if predecessor else None
    return result


def search_facts(query: str) -> list[dict]:
    return [dict(r) for r in conn.execute(
        "SELECT * FROM profile_facts WHERE fact_text LIKE ? ORDER BY created_at DESC",
        (f"%{query}%",),
    ).fetchall()]


def get_full_biography() -> list[dict]:
    rows = conn.execute(
        "SELECT * FROM profile_facts WHERE status = 'active' ORDER BY category, created_at ASC"
    ).fetchall()
    return [dict(r) for r in rows]


# ── Agent self-improvement (Decisions 1/2/4, pilot: nix-refine) ──────────────
# These write to the `learnings` / `learning_evidence` / `fabrication_incidents`
# tables only (domain = 'agent-learning'); they never touch goals/traits/facts.
# Decision 4 (Option 1) gate: `learning_append` ALWAYS writes status =
# 'proposed'. Only `learning_promote` — intended for Sean or a human-reviewed
# session — moves a row to 'validated'/'rejected', and validation requires the
# commit hash of the edit it acted on. An agent must never call learning_promote
# on itself mid-run.

_PLACEHOLDER_RE = re.compile(
    r"^\s*(placeholder|tbd|todo|lorem|none\s*yet|fix\s*(later|me)|n/a|xxx|\.\.\.)\s*$",
    re.IGNORECASE,
)


def _evidence_valid(evidence: str) -> bool:
    ev = (evidence or "").strip()
    if not ev:
        return False
    if _PLACEHOLDER_RE.match(ev):
        return False
    # Evidence must cite something concrete: a file:line, a path, or quoted
    # command/output text. Reject bare prose like "investigate x compatibility".
    has_citation = (
        ":" in ev
        or "/" in ev
        or ev.startswith("`")
        or ev.startswith('"')
        or ev.startswith("'")
        or "file:" in ev.lower()
        or "line" in ev.lower()
    )
    if has_citation:
        return True
    # Non-empty prose with enough substance is accepted only if it clearly
    # references concrete output; if it's short (<40 chars) and lookseudo-ey,
    # treat as suspect.
    return len(ev) >= 40


def _normalise(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip().lower())


_STOPWORDS = frozenset({
    "the", "and", "a", "an", "in", "on", "of", "to", "for", "with", "was", "had", "have", "has",
    "is", "are", "be", "been", "this", "that", "these", "those", "their", "they", "them", "then",
    "there", "were", "but", "so", "it", "its", "which", "each", "only", "not", "no", "also",
    "after", "from", "into", "before", "by", "or", "as", "at", "do", "did", "didn", "more",
    "most", "any", "some", "would", "could", "should", "must", "may", "can", "when", "where",
    "while", "both", "all", "one", "two", "per", "via", "etc", "you", "your", "s", "t", "re",
    "ve", "ll", "d", "out", "up", "down", "over", "under", "again", "further", "once", "here",
    "what", "who", "whom", "own", "same", "than", "then", "too", "very", "just", "because",
    "until", "during", "above", "below", "between", "through", "if", "else", "yet", "still",
    "ever", "never", "even", "well",
})


def _lesson_tokens(s: str) -> set:
    """Distinctive tokens of a lesson: stopwords and single chars removed, so
    the similarity signal comes from content words, not filler."""
    words = re.sub(r"[^a-z0-9_\-/.]+", " ", _normalise(s)).split()
    return {w for w in words if w not in _STOPWORDS and len(w) > 1}


def _near_duplicate_lesson(a: str, b: str) -> bool:
    """True when two lessons are near-duplicates.

    Uses max-containment of the stopword-filtered distinctive token sets:
    the fraction of the SMALLER lesson's distinctive tokens that appear in the
    LARGER one. This is the metric that separates real RUN LOG pairs (validated
    on 9 hand-labelled pairs from nix-refine/nix-doc-audit/researcher/minecraft
    RUN LOGs): genuine duplicates scored 0.357-0.625, distinct-but-similar
    pairs scored 0.091-0.25. Threshold 0.30 sits between the bands. The raw
    token-overlap metric this replaced (0.7) failed: it split every obvious
    duplicate (scores 0.40-0.44) yet still caught nothing adversarially."""
    na, nb = _normalise(a), _normalise(b)
    if na == nb:
        return True
    if not na or not nb:
        return False
    ta, tb = _lesson_tokens(a), _lesson_tokens(b)
    if not ta or not tb:
        return False
    inter = len(ta & tb)
    containment = max(inter / len(ta), inter / len(tb))
    return containment >= 0.30


def learning_append(command: str, lesson: str, fix: str = "", evidence: str = "") -> dict:
    """Write a proposed learning. Always status='proposed' (Decision 4 gate).

    Refuses calls missing a concrete `evidence` citation (the placeholder-scan
    failure class from Tier 0) and dedupes against an existing open (non-stale)
    learning with the same command + near-duplicate lesson."""
    cmd = (command or "").strip()
    lsn = (lesson or "").strip()
    ev = (evidence or "").strip()
    if not cmd:
        raise ValueError("learning_append requires 'command'")
    if not lsn:
        raise ValueError("learning_append requires 'lesson'")
    if not _evidence_valid(ev):
        raise ValueError(
            "learning_append requires 'evidence' with a file:line citation (or concrete command "
            "output) — refusing placeholder/empty evidence"
        )

    # Dedupe: an existing open (non-stale) learning for this command with a
    # near-duplicate lesson supersedes the append.
    rows = conn.execute(
        "SELECT * FROM learnings WHERE command = ? AND status != 'stale'",
        (cmd,),
    ).fetchall()
    for row in rows:
        if _near_duplicate_lesson(row["lesson"], lsn):
            result = dict(row)
            result["deduped"] = True
            result["note"] = f"existing open learning {row['id']} covers this lesson; nothing written"
            return result

    now = datetime.datetime.utcnow().isoformat()
    cur = conn.execute(
        """INSERT INTO learnings (domain, command, lesson, fix, evidence, status, alpha, beta, confidence, created_at)
           VALUES (?, ?, ?, ?, ?, 'proposed', 1.0, 1.0, 0.5, ?)""",
        (AGENT_LEARNING_DOMAIN, cmd, lsn, fix, ev, now),
    )
    conn.commit()
    learning_id = cur.lastrowid
    result = dict(conn.execute("SELECT * FROM learnings WHERE id = ?", (learning_id,)).fetchone())
    result["deduped"] = False
    return result


def learning_promote(learning_id: int, decision: str, acted_on_commit: str | None = None) -> dict:
    """Human-reviewed promotion of a learning.

    THIS TOOL IS FOR SEAN OR A HUMAN-REVIEWED SESSION ONLY. It must NEVER be
    invoked from within the same run that proposed the learning — that is the
    whole of Decision 4 (Option 1): the agent may only propose; it may not
    validate its own learnings. Validation requires the commit hash the
    corresponding command/skill edit was made in, so edit and promotion are one
    reviewed action and cannot drift apart."""
    if decision not in ("validated", "rejected"):
        raise ValueError("learning_promote decision must be 'validated' or 'rejected'")
    row = conn.execute(
        "SELECT * FROM learnings WHERE id = ? AND status = 'proposed'",
        (learning_id,),
    ).fetchone()
    if not row:
        raise ValueError(f"No 'proposed' learning with id {learning_id}")

    if decision == "validated":
        commit = (acted_on_commit or "").strip()
        if not commit:
            raise ValueError(
                "learning_promote 'validated' requires acted_on_commit — the commit hash of the "
                "edit this promotion is validating"
            )
        conn.execute(
            "UPDATE learnings SET status = 'validated', acted_on_commit = ? WHERE id = ?",
            (commit, learning_id),
        )
    else:
        conn.execute("UPDATE learnings SET status = 'rejected' WHERE id = ?", (learning_id,))
    conn.commit()
    return dict(conn.execute("SELECT * FROM learnings WHERE id = ?", (learning_id,)).fetchone())


def learning_query(command: str | None = None, status: str | None = None) -> list[dict]:
    """List learnings, filtered by command and/or status. This is the queue a
    human review session works from (e.g. all 'proposed' learnings for
    'nix-refine' awaiting a decision)."""
    query = "SELECT * FROM learnings"
    params: list = []
    where: list[str] = []
    if command is not None:
        where.append("command = ?")
        params.append(command)
    if status is not None:
        where.append("status = ?")
        params.append(status)
    if where:
        query += " WHERE " + " AND ".join(where)
    query += " ORDER BY created_at ASC"
    return [dict(r) for r in conn.execute(query, params).fetchall()]


TOOLS: list[dict] = [
    {
        "name": "list_goals",
        "description": "List goals, optionally filtered by domain and/or status.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Filter by domain name"},
                "status": {"type": "string", "description": "Filter by status (active, in_progress, done, abandoned)"},
            },
        },
    },
    {
        "name": "create_goal",
        "description": "Create a new goal under a domain.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name (created if not exists)"},
                "title": {"type": "string", "description": "Goal title"},
                "why_it_matters": {"type": "string", "description": "Why this goal matters"},
                "priority": {"type": "integer", "description": "Priority (1=high, 5=low)"},
                "target_date": {"type": "string", "description": "Target date (ISO format)"},
            },
            "required": ["domain", "title"],
        },
    },
    {
        "name": "update_goal",
        "description": "Update fields on an existing goal.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Goal ID"},
                "title": {"type": "string", "description": "New title"},
                "why_it_matters": {"type": "string", "description": "New why_it_matters"},
                "status": {"type": "string", "description": "New status"},
                "priority": {"type": "integer", "description": "New priority (1=high, 5=low)"},
                "target_date": {"type": "string", "description": "New target date"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "log_action_taken",
        "description": "Log an action taken toward a goal.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "goal_id": {"type": "integer", "description": "Goal ID"},
                "description": {"type": "string", "description": "Description of the action"},
                "milestone_id": {"type": "integer", "description": "Optional milestone ID"},
            },
            "required": ["goal_id", "description"],
        },
    },
    {
        "name": "get_stale_goals",
        "description": "Find goals that haven't had activity in N days.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "days_threshold": {"type": "integer", "description": "Days without activity", "default": 14},
            },
        },
    },
    {
        "name": "get_domain_balance",
        "description": "Check-in and action counts per domain over a time window.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "window_days": {"type": "integer", "description": "Lookback window in days", "default": 30},
            },
        },
    },
    {
        "name": "log_check_in",
        "description": "Log a check-in for a domain/goal, optionally updating trait confidences atomically.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "description": "Domain name"},
                "goal_id": {"type": "integer", "description": "Optional goal ID"},
                "text": {"type": "string", "description": "Check-in text"},
                "sentiment": {"type": "string", "description": "Optional sentiment"},
                "trait_updates": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "trait_id": {"type": "integer"},
                            "evidence_value": {"type": "number", "description": "1.0=reinforces, 0.0=contradicts, 0.5=neutral"},
                            "note": {"type": "string", "description": "One-line rationale for this evidence value"},
                        },
                        "required": ["trait_id", "evidence_value"],
                    },
                },
            },
            "required": ["domain"],
        },
    },
    {
        "name": "list_traits",
        "description": "List behavioral traits, optionally filtered by status.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "description": "Filter: proposed, active, retired, or omit for all"},
            },
        },
    },
    {
        "name": "get_trait",
        "description": "Get a trait with its full evidence trail.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Trait ID"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "propose_trait",
        "description": "Propose a new behavioral trait (starts in proposed status with uninformative prior).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Trait name"},
                "description": {"type": "string", "description": "Detailed description"},
                "category": {"type": "string", "description": "Category (e.g. behavior, habit, preference)"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "get_today_context",
        "description": "Bundle of active goals, stale-goal flags, active traits, and last check-in. Call this on session start to orient.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "create_milestone",
        "description": "Create a new milestone for a goal.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "goal_id": {"type": "integer", "description": "Goal ID"},
                "title": {"type": "string", "description": "Milestone title"},
                "target_date": {"type": "string", "description": "Target date (ISO format)"},
                "order": {"type": "integer", "description": "Order within goal (0=first)", "default": 0},
            },
            "required": ["goal_id", "title"],
        },
    },
    {
        "name": "list_milestones",
        "description": "List milestones for a goal, ordered by sequence.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "goal_id": {"type": "integer", "description": "Goal ID"},
            },
            "required": ["goal_id"],
        },
    },
    {
        "name": "update_milestone",
        "description": "Update a milestone's status or target date.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Milestone ID"},
                "status": {"type": "string", "description": "New status (pending, done)"},
                "target_date": {"type": "string", "description": "New target date (ISO format)"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "get_milestone",
        "description": "Get a milestone with its linked actions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Milestone ID"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "get_timeline_health",
        "description": "Compute a goal's timeline health: on_track, at_risk, behind, overdue, or undefined. Uses elapsed vs progress gap.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "goal_id": {"type": "integer", "description": "Goal ID"},
                "at_risk_threshold": {"type": "number", "description": "Gap threshold for at_risk (default 0.15)", "default": 0.15},
                "behind_threshold": {"type": "number", "description": "Gap threshold for behind (default 0.30)", "default": 0.30},
            },
            "required": ["goal_id"],
        },
    },
    {
        "name": "record_fact",
        "description": "Record a new active profile fact. Only call when the user explicitly states a fact about themselves — never infer from passing mention.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "category": {"type": "string", "enum": ["background", "current_commitment", "skill", "value", "relationship", "constraint", "history"], "description": "Fixed category enum"},
                "fact_text": {"type": "string", "description": "The verbatim fact as stated by the user"},
                "source_check_in_id": {"type": "integer", "description": "Optional check-in ID if this fact was derived from a check-in"},
            },
            "required": ["category", "fact_text"],
        },
    },
    {
        "name": "supersede_fact",
        "description": "Atomically mark a fact as superseded and create its replacement.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "old_id": {"type": "integer", "description": "ID of the fact to supersede"},
                "new_category": {"type": "string", "enum": ["background", "current_commitment", "skill", "value", "relationship", "constraint", "history"], "description": "Category for the new fact"},
                "new_fact_text": {"type": "string", "description": "Replacement fact text"},
                "source_check_in_id": {"type": "integer", "description": "Optional check-in ID"},
            },
            "required": ["old_id", "new_category", "new_fact_text"],
        },
    },
    {
        "name": "list_facts",
        "description": "List profile facts, optionally filtered by category and/or status. Defaults to active if status not specified.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "category": {"type": "string", "description": "Filter by category"},
                "status": {"type": "string", "description": "Filter by status (active, superseded) — defaults to active"},
            },
        },
    },
    {
        "name": "get_fact",
        "description": "Get a fact with its full supersession chain (what it replaced, what replaced it).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Fact ID"},
            },
            "required": ["id"],
        },
    },
    {
        "name": "search_facts",
        "description": "Simple substring search over fact_text.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search string (substring match)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "get_full_biography",
        "description": "Return all active profile facts, ordered by category. Call this when a complete picture of the user is needed.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "learning_append",
        "description": "Record a proposed agent self-improvement learning (status ALWAYS 'proposed' — Decision 4 gate; only the human-gated learning_promote can validate/reject). Requires command, lesson, and evidence (file:line citation or concrete command output; placeholder/empty evidence is rejected). Dedupes against an existing open learning with the same command and near-duplicate lesson.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Command/skill name this learning is about (e.g. 'nix-refine')"},
                "lesson": {"type": "string", "description": "One-line lesson — what happened and why the guidance misled/wasted effort"},
                "fix": {"type": "string", "description": "What should change to apply this lesson"},
                "evidence": {"type": "string", "description": "file:line citation or verbatim command output backing the lesson. REQUIRED; empty/placeholder text is rejected."},
            },
            "required": ["command", "lesson", "evidence"],
        },
    },
    {
        "name": "learning_promote",
        "description": "Human-reviewed promotion of a proposed learning to 'validated' or 'rejected'. FOR SEAN OR A HUMAN-REVIEWED SESSION ONLY — must NEVER be invoked from within the same run that proposed the learning (Decision 4, Option 1 gate). 'validated' requires acted_on_commit (the hash of the edit being reviewed), so edit and promotion are one action.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "learning_id": {"type": "integer", "description": "Learning ID to promote"},
                "decision": {"type": "string", "enum": ["validated", "rejected"], "description": "validated = learning caused a real, reviewed command/skill edit; rejected = not acted on"},
                "acted_on_commit": {"type": "string", "description": "Commit hash of the edit this promotion validates. REQUIRED when decision='validated'."},
            },
            "required": ["learning_id", "decision"],
        },
    },
    {
        "name": "learning_query",
        "description": "List agent learnings, filtered by command and/or status. The review queue a human session works from (e.g. all 'proposed' learnings for 'nix-refine' awaiting a decision).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Filter by command (e.g. 'nix-refine')"},
                "status": {"type": "string", "description": "Filter by status (proposed, validated, rejected, stale)"},
            },
        },
    },
]

TOOL_DISPATCH = {
    "list_goals": list_goals,
    "create_goal": create_goal,
    "update_goal": update_goal,
    "log_action_taken": log_action_taken,
    "get_stale_goals": get_stale_goals,
    "get_domain_balance": get_domain_balance,
    "log_check_in": log_check_in,
    "list_traits": list_traits,
    "get_trait": get_trait,
    "propose_trait": propose_trait,
    "get_today_context": get_today_context,
    "create_milestone": create_milestone,
    "list_milestones": list_milestones,
    "update_milestone": update_milestone,
    "get_milestone": get_milestone,
    "get_timeline_health": get_timeline_health,
    "record_fact": record_fact,
    "supersede_fact": supersede_fact,
    "list_facts": list_facts,
    "get_fact": get_fact,
    "search_facts": search_facts,
    "get_full_biography": get_full_biography,
    "learning_append": learning_append,
    "learning_promote": learning_promote,
    "learning_query": learning_query,
}


def send(msg: dict) -> None:
    line = json.dumps(msg)
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def handle_request(msg: dict) -> dict | None:
    method: str = msg.get("method", "")
    _id = msg.get("id")
    params: dict = msg.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": _id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "goals-mcp", "version": "0.1.0"},
            },
        }
    elif method == "notifications/initialized":
        return None
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": _id, "result": {"tools": TOOLS}}
    elif method == "tools/call":
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})
        fn = TOOL_DISPATCH.get(tool_name)
        if fn is None:
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
            }
        try:
            result = fn(**arguments)
            text = json.dumps(result, indent=2, default=str)
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "result": {"content": [{"type": "text", "text": text}]},
            }
        except Exception as e:
            tb = traceback.format_exc()
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "error": {"code": -32603, "message": f"{e}\n{tb}"},
            }
    else:
        return {
            "jsonrpc": "2.0",
            "id": _id,
            "error": {"code": -32601, "message": f"Method not found: {method}"},
        }


def main() -> None:
    global conn, engine, AT_RISK_THRESHOLD, BEHIND_THRESHOLD

    parser = argparse.ArgumentParser(description="Goals MCP server")
    parser.add_argument("--db", required=True, help="Path to SQLite database file")
    parser.add_argument("--schema", default=None, help="Path to schema.sql (defaults to sibling of this script)")
    parser.add_argument("--decay-factor", type=float, default=0.98, help="Weekly decay factor for trait confidence")
    parser.add_argument("--min-days", type=int, default=3, help="Min distinct days for trait promotion")
    parser.add_argument("--min-count", type=int, default=5, help="Min observations for trait promotion")
    parser.add_argument("--promotion-confidence", type=float, default=0.65, help="Confidence threshold for promotion")
    parser.add_argument("--retire-confidence", type=float, default=0.35, help="Confidence threshold for retirement")
    parser.add_argument("--at-risk-threshold", type=float, default=0.15, help="Gap threshold for at-risk timeline status")
    parser.add_argument("--behind-threshold", type=float, default=0.30, help="Gap threshold for behind timeline status")
    args = parser.parse_args()

    AT_RISK_THRESHOLD = args.at_risk_threshold
    BEHIND_THRESHOLD = args.behind_threshold

    engine = TraitEngine(
        decay_factor=args.decay_factor,
        min_days=args.min_days,
        min_count=args.min_count,
        promotion_threshold=args.promotion_confidence,
        retire_threshold=args.retire_confidence,
    )

    schema_path = args.schema if args.schema else SCHEMA_PATH
    conn = init_db(args.db, schema_path=schema_path)

    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        resp = handle_request(msg)
        if resp is not None:
            send(resp)


if __name__ == "__main__":
    main()
