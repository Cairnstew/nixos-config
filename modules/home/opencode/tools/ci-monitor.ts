import { execSync } from "node:child_process";

const MAX_BUFFER = 10 * 1024 * 1024;
const GH_TIMEOUT = 30_000;

function gh(
  cmd: string,
  timeoutMs: number = GH_TIMEOUT,
): string {
  const out = execSync(`gh ${cmd} 2>&1`, {
    encoding: "utf-8",
    timeout: timeoutMs,
    maxBuffer: MAX_BUFFER,
  });
  return out.trim();
}

function detectRepo(): string | null {
  try {
    const raw = execSync("git remote get-url origin", {
      encoding: "utf-8",
      timeout: 10_000,
      maxBuffer: MAX_BUFFER,
    }).trim();

    // SSH: git@github.com:owner/repo.git
    const ssh = raw.match(/git@github\.com:([^/]+\/[^/]+?)(?:\.git)?$/);
    if (ssh) return ssh[1];

    // HTTPS: https://github.com/owner/repo.git or without .git
    const https = raw.match(/https:\/\/github\.com\/([^/]+\/[^/]+?)(?:\.git)?$/);
    if (https) return https[1];

    return null;
  } catch {
    return null;
  }
}

function detectBranch(): string {
  try {
    return execSync("git branch --show-current", {
      encoding: "utf-8",
      timeout: 10_000,
      maxBuffer: MAX_BUFFER,
    }).trim();
  } catch {
    return "main";
  }
}

function headSha(): string {
  return execSync("git rev-parse HEAD", {
    encoding: "utf-8",
    timeout: 10_000,
    maxBuffer: MAX_BUFFER,
  }).trim();
}

function findRunBySha(
  repo: string,
  branch: string,
  sha: string,
): string | null {
  for (let attempt = 0; attempt < 8; attempt++) {
    try {
      const raw = gh(
        `run list --repo ${repo} --branch ${branch} --json databaseId,headSha --limit 10`,
      );
      const runs = JSON.parse(raw) as Array<{
        databaseId: number;
        headSha: string;
      }>;
      const match = runs.find((r) => r.headSha === sha);
      if (match) return String(match.databaseId);
    } catch {
      // gh call failed — retry
    }
    if (attempt < 7) {
      execSync("sleep 10");
    }
  }
  return null;
}

function fetchRunDetails(repo: string, runId: string): any {
  const raw = gh(
    `run view ${runId} --repo ${repo} --json status,conclusion,headBranch,headSha,event,url,createdAt,updatedAt,jobs`,
  );
  return JSON.parse(raw);
}

function fetchLogExcerpt(repo: string, runId: string): string {
  try {
    const raw = gh(`run view ${runId} --repo ${repo} --log-failed`);
    const lines = raw.split("\n");
    const last100 = lines.slice(-100).join("\n");
    if (last100.length > 2000) {
      return last100.slice(-2000);
    }
    return last100;
  } catch {
    return "(could not fetch logs)";
  }
}

function buildResult(
  details: any,
  repo: string,
  logExcerpt: string | null,
): string {
  const durationSeconds = details.createdAt && details.updatedAt
    ? Math.round(
        (new Date(details.updatedAt).getTime() -
          new Date(details.createdAt).getTime()) /
          1000,
      )
    : null;

  const jobs = (details.jobs || []).map((j: any) => ({
    name: j.name,
    conclusion: j.conclusion,
  }));

  const failedJobs = jobs
    .filter((j: any) => j.conclusion !== "success")
    .map((j: any) => j.name);

  const result: Record<string, any> = {
    status: details.status,
    conclusion: details.conclusion,
    run_id: details.databaseId || details.id,
    branch: details.headBranch,
    repo,
    url: details.url,
    duration_seconds: durationSeconds,
    jobs,
    failed_jobs: failedJobs,
    log_excerpt: details.conclusion !== "success" ? logExcerpt : null,
  };

  return JSON.stringify(result, null, 2);
}

export default {
  description:
    "Monitor GitHub Actions CI runs. Supports blocking watch (waits for run to complete), listing recent runs, and viewing a specific run with failure logs. Returns structured JSON.",
  args: {
    action: {
      type: "string",
      description:
        "Action: 'watch' (block until run completes), 'list' (recent runs), or 'view' (single run details). Default: watch.",
    },
    run_id: {
      type: "string",
      description:
        "Run ID for watch/view. Auto-detected via SHA match if omitted (watch only). Required for view.",
    },
    branch: {
      type: "string",
      description: "Branch name. Default: current branch from git.",
    },
    repo: {
      type: "string",
      description:
        "Owner/repo (e.g. Cairnstew/nixos-config). Auto-detected from git remote if omitted.",
    },
    timeout: {
      type: "string",
      description:
        "Max seconds to wait for watch action. Default: 1800 (30 min).",
    },
  },
  async execute(
    args: {
      action?: string;
      run_id?: string;
      branch?: string;
      repo?: string;
      timeout?: string;
    },
  ) {
    const action = args.action || "watch";

    // Resolve repo
    let repo = args.repo;
    if (!repo) {
      repo = detectRepo();
      if (!repo) {
        return JSON.stringify(
          {
            error: "repo_detection_failed",
            message:
              "Could not detect repo from git remote. Pass 'repo' explicitly (e.g. Cairnstew/nixos-config).",
          },
          null,
          2,
        );
      }
    }

    const branch = args.branch || detectBranch();

    // ── list ──────────────────────────────────────────────────────────────
    if (action === "list") {
      try {
        const raw = gh(
          `run list --repo ${repo} --branch ${branch} --limit 10 --json databaseId,status,conclusion,headBranch,headSha,event,createdAt,updatedAt`,
        );
        return raw;
      } catch (e: any) {
        return JSON.stringify(
          {
            error: "gh_command_failed",
            message: (e.stderr || e.stdout || e.message || String(e)).trim(),
            command: `gh run list --repo ${repo} --branch ${branch}`,
          },
          null,
          2,
        );
      }
    }

    // ── view ──────────────────────────────────────────────────────────────
    if (action === "view") {
      if (!args.run_id) {
        return JSON.stringify(
          {
            error: "missing_run_id",
            message:
              "action=view requires 'run_id'. Use action=list to find a run ID, or action=watch to auto-detect.",
          },
          null,
          2,
        );
      }

      try {
        const details = fetchRunDetails(repo, args.run_id);
        const logExcerpt =
          details.conclusion !== "success"
            ? fetchLogExcerpt(repo, args.run_id)
            : null;
        return buildResult(details, repo, logExcerpt);
      } catch (e: any) {
        return JSON.stringify(
          {
            error: "gh_command_failed",
            message: (e.stderr || e.stdout || e.message || String(e)).trim(),
            command: `gh run view ${args.run_id} --repo ${repo}`,
          },
          null,
          2,
        );
      }
    }

    // ── watch (default) ───────────────────────────────────────────────────
    const timeout = parseInt(args.timeout || "1800", 10);

    // Resolve run_id via SHA match if not provided
    let runId = args.run_id;
    if (!runId) {
      let sha: string;
      try {
        sha = headSha();
      } catch (e: any) {
        return JSON.stringify(
          {
            error: "git_error",
            message: `Could not determine HEAD SHA: ${(e.stderr || e.message || String(e)).trim()}`,
          },
          null,
          2,
        );
      }

      runId = findRunBySha(repo, branch, sha);
      if (!runId) {
        return JSON.stringify(
          {
            error: "run_not_found",
            message: `No run found for commit ${sha} on branch ${branch} after 80s`,
            sha,
            branch,
          },
          null,
          2,
        );
      }
    }

    // Block until run completes
    try {
      gh(`run watch ${runId} --repo ${repo} --exit-status`, timeout * 1000);
    } catch (e: any) {
      // execSync throws on non-zero exit (run failed/cancelled) AND on timeout.
      // Distinguish: if e.killed is true, the process was killed by execSync timeout.
      if (e.killed) {
        // The watch process was killed — fetch current status before returning
        let lastStatus = "unknown";
        try {
          const raw = gh(
            `run view ${runId} --repo ${repo} --json status`,
          );
          const parsed = JSON.parse(raw);
          lastStatus = parsed.status || "unknown";
        } catch {
          // best effort
        }
        return JSON.stringify(
          {
            error: "timeout",
            message: `Run ${runId} did not complete within ${timeout}s`,
            last_status: lastStatus,
            run_id: runId,
            url: `https://github.com/${repo}/actions/runs/${runId}`,
          },
          null,
          2,
        );
      }
      // Non-zero exit from --exit-status (run failed/cancelled) — expected, proceed to fetch details
    }

    // Fetch full details and build result
    try {
      const details = fetchRunDetails(repo, runId);
      const logExcerpt =
        details.conclusion !== "success"
          ? fetchLogExcerpt(repo, runId)
          : null;
      return buildResult(details, repo, logExcerpt);
    } catch (e: any) {
      return JSON.stringify(
        {
          error: "gh_command_failed",
          message: (e.stderr || e.stdout || e.message || String(e)).trim(),
          command: `gh run view ${runId} --repo ${repo} --json ...`,
        },
        null,
        2,
      );
    }
  },
};
