#!/usr/bin/env python3
"""Learning-promoter watcher: polls the goals DB for proposed learnings and
dispatches the promoter agent via `opencode run --attach` to a persistent
`opencode serve` instance.

Designed to run under a systemd user timer (every ~1 min). The timer fires,
this script checks the DB, and if there are proposed learnings and no active
promotion, it sends /learning-promote to the headless server.

Architecture (v2 — no tmux):
  - A persistent `opencode serve` systemd service hosts the opencode runtime.
  - This watcher sends commands via `opencode run --attach http://localhost:<port>`.
  - No tmux, no send-keys, no pipe-pane, no zombie detection.
  - Completion is detected by the command exiting successfully.
  - A state file tracks active promotions for overlap prevention.

Improvements over v1 (tmux-based):
  - Eliminates tmux dependency and all tmux-related fragility.
  - API-based communication via opencode serve (no timing/retry heuristics).
  - Proper promotion timeout (configurable, default 30min).
  - No-verdicts reconciliation (force-rejects stale never-triaged learnings).
  - Structured JSON output parsing for completion detection.

Environment variables (set by the Nix derivation):
  GOALS_DB            — path to the goals SQLite database
  REPO_DIR            — path to the nixos-config repo
  OPENCODE_SERVER_URL — opencode serve base URL (default: http://127.0.0.1:4096)
  PROMOTION_TIMEOUT   — max seconds for a promotion cycle (default: 1800 = 30min)
  STALENESS_THRESHOLD — seconds before a never-triaged learning is force-rejected (default: 1800 = 30min)
  STATE_DIR           — directory for promotion state files (default: ~/.local/share/opencode)
"""

import json
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

GOALS_DB = os.environ.get(
    "GOALS_DB", os.path.expanduser("~/.local/share/goals/goals.db")
)
REPO_DIR = os.environ.get("REPO_DIR", os.path.expanduser("~/nixos-config"))
OPENCODE_SERVER_URL = os.environ.get("OPENCODE_SERVER_URL", "http://127.0.0.1:4096")
PROMOTION_TIMEOUT = int(os.environ.get("PROMOTION_TIMEOUT", "1800"))
STALENESS_THRESHOLD = int(os.environ.get("STALENESS_THRESHOLD", "1800"))
STATE_DIR = os.environ.get(
    "STATE_DIR", os.path.expanduser("~/.local/share/opencode")
)
STATE_FILE = os.path.join(STATE_DIR, "learning-promoter.state")
COMMAND_TIMEOUT = int(os.environ.get("COMMAND_TIMEOUT", "600"))


def log(msg: str) -> None:
    """Print with timestamp for systemd journal visibility."""
    print(f"[learning-promoter-watcher] {msg}", flush=True)


# ── Database helpers ─────────────────────────────────────────────────────────


def get_db_connection(db_path: str) -> sqlite3.Connection:
    """Get a SQLite connection with WAL mode enabled.

    WAL allows concurrent readers and one writer, reducing lock contention
    when the agent and watcher access the DB simultaneously.
    """
    conn = sqlite3.connect(db_path, timeout=5)
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def has_proposed_learnings(db_path: str) -> bool:
    """Return True if the goals DB contains any proposed learnings."""
    if not os.path.exists(db_path):
        log(f"goals DB not found at {db_path}")
        return False
    try:
        conn = get_db_connection(db_path)
        cur = conn.execute("SELECT 1 FROM learnings WHERE status = 'proposed' LIMIT 1")
        result = cur.fetchone() is not None
        conn.close()
        return result
    except sqlite3.OperationalError as e:
        log(f"DB query failed (locked or corrupt): {e}")
        return False


def count_proposed_learnings(db_path: str) -> int:
    """Return the number of proposed learnings in the queue."""
    if not os.path.exists(db_path):
        return 0
    try:
        conn = get_db_connection(db_path)
        cur = conn.execute("SELECT COUNT(*) FROM learnings WHERE status = 'proposed'")
        count = cur.fetchone()[0]
        conn.close()
        return count
    except sqlite3.OperationalError:
        return 0


def reconcile_partial_verdicts(db_path: str) -> int:
    """Force-reject proposed learnings that have partial verdicts from a crashed session.

    If a promoter crashed mid-triage, some learnings may have 1-2 verdicts but
    not all 3. These are stuck: no new promoter will re-triage them (they already
    have verdicts), but they can't be promoted (not unanimous). Force-reject them
    so the next watcher cycle starts fresh.

    Returns the number of learnings rejected.
    """
    if not os.path.exists(db_path):
        return 0
    try:
        conn = get_db_connection(db_path)
        # Find proposed learnings with fewer than 3 re-derived verdicts
        cur = conn.execute("""
            SELECT l.id
            FROM learnings l
            LEFT JOIN (
                SELECT learning_id, COUNT(*) as verdict_count
                FROM review_verdicts
                WHERE rederivation_method IS NOT NULL
                GROUP BY learning_id
            ) v ON l.id = v.learning_id
            WHERE l.status = 'proposed'
              AND COALESCE(v.verdict_count, 0) > 0
              AND COALESCE(v.verdict_count, 0) < 3
        """)
        stuck_ids = [row[0] for row in cur.fetchall()]

        if stuck_ids:
            for lid in stuck_ids:
                conn.execute(
                    "UPDATE learnings SET status = 'rejected', "
                    "rejection_reason = 'partial verdicts from crashed session' "
                    "WHERE id = ?",
                    (lid,),
                )
                log(f"force-rejected learning {lid} (partial verdicts from crash)")
            conn.commit()

        conn.close()
        return len(stuck_ids)
    except sqlite3.OperationalError as e:
        log(f"verdict reconciliation failed (locked or corrupt): {e}")
        return 0


def reconcile_stale_learnings(db_path: str) -> int:
    """Force-reject proposed learnings that were never triaged.

    If a learning has been proposed for longer than STALENESS_THRESHOLD and has
    zero verdicts, the promoter never got to it (crashed before triage, or was
    never launched). Force-reject so the queue stays clean.

    Returns the number of learnings rejected.
    """
    if not os.path.exists(db_path):
        return 0
    try:
        conn = get_db_connection(db_path)
        cur = conn.execute("""
            SELECT l.id
            FROM learnings l
            LEFT JOIN (
                SELECT learning_id, COUNT(*) as verdict_count
                FROM review_verdicts
                GROUP BY learning_id
            ) v ON l.id = v.learning_id
            WHERE l.status = 'proposed'
              AND COALESCE(v.verdict_count, 0) = 0
              AND (strftime('%s', 'now') - strftime('%s', l.created_at)) > ?
        """, (STALENESS_THRESHOLD,))
        stale_ids = [row[0] for row in cur.fetchall()]

        if stale_ids:
            for lid in stale_ids:
                conn.execute(
                    "UPDATE learnings SET status = 'rejected', "
                    "rejection_reason = 'never triaged (stale beyond threshold)' "
                    "WHERE id = ?",
                    (lid,),
                )
                log(f"force-rejected learning {lid} (stale, zero verdicts)")
            conn.commit()

        conn.close()
        return len(stale_ids)
    except sqlite3.OperationalError as e:
        log(f"stale reconciliation failed (locked or corrupt): {e}")
        return 0


def reconcile_complete_unpromoted(db_path: str) -> int:
    """Force-reject proposed learnings with 3+ complete verdicts that were never promoted.

    These are stuck: the agent completed triage but crashed before calling
    learning_promote. They can't be promoted without the agent (need harness
    re-derivation), so we force-reject them to keep the queue clean.
    """
    if not os.path.exists(db_path):
        return 0
    try:
        conn = get_db_connection(db_path)
        cur = conn.execute("""
            SELECT l.id
            FROM learnings l
            LEFT JOIN (
                SELECT learning_id, COUNT(*) as verdict_count
                FROM review_verdicts
                WHERE rederivation_method IS NOT NULL
                GROUP BY learning_id
            ) v ON l.id = v.learning_id
            WHERE l.status = 'proposed'
              AND COALESCE(v.verdict_count, 0) >= 3
        """)
        stuck_ids = [row[0] for row in cur.fetchall()]

        if stuck_ids:
            for lid in stuck_ids:
                conn.execute(
                    "UPDATE learnings SET status = 'rejected', "
                    "rejection_reason = 'complete but un-promoted (agent crashed)' "
                    "WHERE id = ?",
                    (lid,),
                )
                log(f"force-rejected learning {lid} (complete but un-promoted)")
            conn.commit()

        conn.close()
        return len(stuck_ids)
    except sqlite3.OperationalError as e:
        log(f"unpromoted reconciliation failed: {e}")
        return 0


# ── Server health ────────────────────────────────────────────────────────────


def _find_opencode_serve_pid() -> int | None:
    """Find the PID of the opencode-serve process."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "opencode serve"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            return int(result.stdout.strip().split("\n")[0])
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def _read_cpu_ticks(pid: int) -> int | None:
    """Read cumulative CPU ticks from /proc/{pid}/stat (utime + stime)."""
    try:
        with open(f"/proc/{pid}/stat", "r") as f:
            parts = f.read().split()
            return int(parts[13]) + int(parts[14])
    except (FileNotFoundError, IndexError, ValueError):
        return None


def _is_cpu_hung(pid: int, threshold: float = 90, window: int = 60) -> bool:
    """Check if a process has been using >threshold% CPU for >window seconds.

    Uses /proc/{pid}/stat to read cumulative CPU time, compared across
    two samples taken `window` seconds apart.
    """
    ticks1 = _read_cpu_ticks(pid)
    if ticks1 is None:
        return False

    time.sleep(window)

    ticks2 = _read_cpu_ticks(pid)
    if ticks2 is None:
        return False

    cpu_count = os.cpu_count() or 1
    delta_ticks = ticks2 - ticks1
    delta_seconds = window
    cpu_pct = (delta_ticks / (delta_seconds * 100)) * 100  # ticks are in 1/100s

    return cpu_pct > (threshold * cpu_count)


def server_is_healthy(url: str) -> bool:
    """Check if the opencode serve instance is responsive, not just alive.

    Combines an HTTP health check with CPU monitoring to detect hung servers
    that are still serving HTTP but not processing requests (CPU spin,
    infinite loop — issues #32965, #36984).
    """
    # HTTP check
    try:
        result = subprocess.run(
            ["curl", "-sf", "--max-time", "5", f"{url}/session"],
            capture_output=True, timeout=10,
        )
        if result.returncode != 0:
            return False
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False

    # CPU check: detect hung server (CPU spin, infinite loop)
    try:
        pid = _find_opencode_serve_pid()
        if pid and _is_cpu_hung(pid, threshold=90, window=60):
            log(f"opencode-serve (PID {pid}) CPU usage >90% for >60s — likely hung")
            return False
    except Exception as e:
        log(f"CPU check failed (non-fatal): {e}")

    return True


# ── Promotion state tracking ─────────────────────────────────────────────────


def is_promotion_running() -> bool:
    """Check if a promotion cycle is already active.

    Uses a state file containing the PID of the opencode run process.
    If the process is still running, a promotion is in progress.
    """
    if not os.path.exists(STATE_FILE):
        return False
    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
        pid = state.get("pid")
        if pid and os.path.exists(f"/proc/{pid}"):
            return True
        # Stale state file — process no longer exists
        remove_state()
        return False
    except (json.JSONDecodeError, OSError):
        remove_state()
        return False


def promotion_has_timed_out() -> bool:
    """Check if the current promotion cycle has exceeded PROMOTION_TIMEOUT."""
    if not os.path.exists(STATE_FILE):
        return False
    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
        started = state.get("started_at")
        if started:
            elapsed = time.time() - started
            if elapsed > PROMOTION_TIMEOUT:
                log(f"promotion timed out after {elapsed:.0f}s (limit: {PROMOTION_TIMEOUT}s)")
                return True
        return False
    except (json.JSONDecodeError, OSError):
        return False


def save_state(pid: int) -> None:
    """Record that a promotion cycle is running."""
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump({"pid": pid, "started_at": time.time()}, f)


def remove_state() -> None:
    """Clear the promotion state file."""
    try:
        os.unlink(STATE_FILE)
    except FileNotFoundError:
        pass


# ── Command dispatch ─────────────────────────────────────────────────────────


def send_learning_promote(server_url: str) -> bool:
    """Send /learning-promote to the opencode server via `opencode run --attach`.

    Uses --attach to connect to the persistent serve instance, --auto to
    bypass permission dialogs, and --format json for structured output.

    Tracks the subprocess PID (not the watcher PID) so that overlap
    prevention correctly detects hung subprocesses.

    Returns True if the command completed successfully.
    """
    cmd = [
        "opencode", "run",
        "--attach", server_url,
        "--auto",
        "--format", "json",
        "--", "/learning-promote",
    ]

    log(f"dispatching: {' '.join(cmd)}")

    try:
        proc = subprocess.Popen(
            cmd,
            cwd=REPO_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        # Track subprocess PID (not watcher PID) for overlap prevention
        save_state(proc.pid)

        try:
            stdout, stderr = proc.communicate(timeout=COMMAND_TIMEOUT)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            log(f"command timed out after {COMMAND_TIMEOUT}s")
            return False

        if proc.returncode == 0:
            # Parse JSON output for structured completion info
            try:
                for line in stdout.strip().split("\n"):
                    if line.strip():
                        event = json.loads(line)
                        if event.get("type") == "message":
                            log(f"promoter response: {event.get('content', '')[:200]}")
            except (json.JSONDecodeError, ValueError):
                # Non-JSON output is fine — command succeeded
                if stdout.strip():
                    log(f"promoter output: {stdout.strip()[:200]}")
            return True
        else:
            log(f"command failed (exit {proc.returncode})")
            if stderr:
                log(f"stderr: {stderr.strip()[:500]}")
            return False

    except FileNotFoundError:
        log("opencode binary not found in PATH")
        return False
    except Exception as e:
        log(f"command failed: {e}")
        return False


# ── Main ─────────────────────────────────────────────────────────────────────


def main() -> int:
    # Check opencode is available
    try:
        subprocess.run(
            ["opencode", "--version"],
            capture_output=True, check=True, timeout=5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        log("opencode not found — skipping")
        return 0

    # Step 1: Check server health
    if not server_is_healthy(OPENCODE_SERVER_URL):
        log(f"opencode serve not healthy at {OPENCODE_SERVER_URL} — skipping")
        log("ensure the opencode-serve systemd service is running")
        return 0

    # Step 2: Check if a promotion is already running (BEFORE reconciliation)
    # This prevents reconciliation from killing learnings that are actively
    # being triaged by a running promoter session.
    if is_promotion_running():
        log("promotion already running, skipping")
        return 0

    # Step 3: Check for timeout on previous promotion
    if promotion_has_timed_out():
        log("previous promotion timed out, cleaning up state")
        remove_state()

    # Step 4: Reconcile partial verdicts from any crashed sessions
    # Only runs when no promotion is active — safe to force-reject stuck learnings.
    reconciled = reconcile_partial_verdicts(GOALS_DB)
    if reconciled > 0:
        log(f"reconciled {reconciled} partial learnings from crash")

    # Step 5: Reconcile stale never-triaged learnings
    # Only runs when no promotion is active — avoids killing learnings that are
    # queued but haven't been reached yet in a sequential batch.
    stale = reconcile_stale_learnings(GOALS_DB)
    if stale > 0:
        log(f"reconciled {stale} stale learnings (never triaged)")

    # Step 6: Reconcile complete but un-promoted learnings
    # These have 3+ complete verdicts but the agent crashed before calling
    # learning_promote. They're stuck and will never be promoted.
    unpromoted = reconcile_complete_unpromoted(GOALS_DB)
    if unpromoted > 0:
        log(f"reconciled {unpromoted} complete but un-promoted learnings")

    # Step 7: Check queue
    if not has_proposed_learnings(GOALS_DB):
        # Clean up stale state if queue is empty
        if os.path.exists(STATE_FILE):
            log("queue empty, cleaning up stale state")
            remove_state()
        return 0

    proposed_count = count_proposed_learnings(GOALS_DB)
    log(f"{proposed_count} proposed learning(s) in queue")

    # Step 8: Write state BEFORE dispatching to prevent overlap
    # Note: save_state() is called again inside send_learning_promote() with
    # the subprocess PID — this initial save is a race-prevention guard.
    save_state(os.getpid())

    # Step 9: Send the promotion command
    log("sending /learning-promote to opencode serve")
    success = send_learning_promote(OPENCODE_SERVER_URL)

    if not success:
        log("promotion dispatch failed, will retry on next cycle")
        remove_state()
        return 1

    log("promotion cycle completed")
    remove_state()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log(f"unexpected error: {e}")
        remove_state()
        sys.exit(1)
