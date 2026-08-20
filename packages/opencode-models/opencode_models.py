#!/usr/bin/env python3
"""Query LLM model pricing, usage limits, and capabilities from models.dev.

models.dev is the model catalog that powers OpenCode's `/models` browser and the
https://opencode.ai/go page. Its single JSON endpoint (https://models.dev/api.json)
lists every provider and model with per-1M-token pricing, context/output limits,
and capability flags (reasoning, tool calling, vision, structured output, ...).

This script fetches that dump (cached under $XDG_CACHE_HOME/opencode/ for 12h),
filters it, and prints a cost-ranked table so you can pick the most cost-effective
model for a given job. Defaults to the `opencode-go` provider (the OpenCode Go
subscription), but `--provider all` covers the whole catalog.

Zero dependencies — Python stdlib only.
"""

import argparse
import json
import os
import sys
import time
import urllib.request

API_URL = "https://models.dev/api.json"
DEFAULT_PROVIDER = "opencode-go"
CACHE_TTL_SECONDS = 12 * 3600
USER_AGENT = "opencode-models/1.0 (nixos-config)"

# Capability flag groups surfaced in the table / selectable via --capability.
CAP_GROUPS = {
    "tools": "tool calling",
    "vision": "image input",
    "multimodal": "any non-text input (image/audio/video)",
    "pdf": "pdf input",
    "audio": "audio input",
    "reasoning": "explicit reasoning / thinking",
    "structured": "structured output",
    "weights": "open weights",
    "interleaved": "interleaved reasoning stream",
}


# ── Fetch + cache ─────────────────────────────────────────────────────────────


def cache_path():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(
        os.path.expanduser("~"), ".cache"
    )
    return os.path.join(base, "opencode", "models.dev.json")


def load_catalog(refresh: bool) -> dict:
    path = cache_path()
    data = None

    if not refresh and os.path.exists(path):
        age = time.time() - os.path.getmtime(path)
        if age < CACHE_TTL_SECONDS:
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    data = json.load(fh)
            except (OSError, ValueError):
                data = None

    if data is None:
        try:
            req = urllib.request.Request(API_URL, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
            data = json.loads(raw)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            tmp = path + ".tmp"
            with open(tmp, "wb") as fh:
                fh.write(raw)
            os.replace(tmp, path)
            sys.stderr.write(f"[refreshed] {API_URL} -> {path}\n")
        except Exception as exc:  # noqa: BLE001 — network errors are expected
            if os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8") as fh:
                        data = json.load(fh)
                    sys.stderr.write(f"[warn] fetch failed ({exc}); using stale cache\n")
                except (OSError, ValueError):
                    data = None
            if data is None:
                sys.stderr.write(f"error: cannot fetch {API_URL}: {exc}\n")
                sys.exit(1)

    return data


# ── Model helpers ─────────────────────────────────────────────────────────────


def input_modalities(model: dict) -> list:
    return (model.get("modalities") or {}).get("input") or []


def capabilities(model: dict) -> set:
    mods = input_modalities(model)
    caps = set()
    if model.get("tool_call"):
        caps.add("tools")
    if "image" in mods or model.get("attachment"):
        caps.add("vision")
    if any(m in mods for m in ("image", "audio", "video")):
        caps.add("multimodal")
    if "pdf" in mods:
        caps.add("pdf")
    if "audio" in mods:
        caps.add("audio")
    if model.get("reasoning"):
        caps.add("reasoning")
    if model.get("structured_output"):
        caps.add("structured")
    if model.get("open_weights"):
        caps.add("weights")
    if model.get("interleaved"):
        caps.add("interleaved")
    return caps


def price(model: dict, key: str) -> float | None:
    return (model.get("cost") or {}).get(key)


def blend_price(model: dict, w_in: float, w_cache: float, w_out: float) -> float:
    inp = price(model, "input") or 0.0
    out = price(model, "output") or 0.0
    # cache_read is what agentic coding actually pays; fall back to input when a
    # provider doesn't price cached reads separately.
    cache = price(model, "cache_read")
    if cache is None:
        cache = inp
    total = w_in + w_cache + w_out
    return (w_in * inp + w_cache * cache + w_out * out) / total


def collect_models(catalog: dict, provider: str) -> list:
    if provider == "all":
        records = []
        for pid, pdata in catalog.items():
            if not isinstance(pdata, dict) or "models" not in pdata:
                continue
            for model in (pdata.get("models") or {}).values():
                rec = dict(model)
                rec["provider"] = pid
                rec.setdefault("id", rec.get("name", "?"))
                records.append(rec)
        return records

    pdata = catalog.get(provider)
    if not isinstance(pdata, dict) or "models" not in pdata:
        avail = sorted(
            k for k, v in catalog.items() if isinstance(v, dict) and "models" in v
        )
        sys.stderr.write(
            f"error: provider '{provider}' not found in models.dev.\n"
            f"available providers ({len(avail)}): {', '.join(avail)}\n"
        )
        sys.exit(1)

    records = []
    for model in (pdata.get("models") or {}).values():
        rec = dict(model)
        rec["provider"] = provider
        rec.setdefault("id", rec.get("name", "?"))
        records.append(rec)
    return records


# ── Formatting ────────────────────────────────────────────────────────────────


def fmt_money(value: float | None) -> str:
    if value is None:
        return "—"
    if value == 0:
        return "$0"
    s = f"{value:.5f}".rstrip("0").rstrip(".")
    return "$" + (s or "0")


def fmt_tokens(value: int | None) -> str:
    if value is None:
        return "—"
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if value >= 1000:
        return f"{value / 1000:.0f}K"
    return str(value)


def model_label(rec: dict, show_provider: bool) -> str:
    mid = rec.get("id") or rec.get("name") or "?"
    if show_provider:
        return f"{rec.get('provider', '?')}/{mid}"
    return mid


def sort_key(rec: dict, sort: str, w_in: float, w_cache: float, w_out: float):
    if sort == "blend":
        return (blend_price(rec, w_in, w_cache, w_out), rec.get("id", ""))
    if sort == "input":
        return (price(rec, "input") or 0.0, rec.get("id", ""))
    if sort == "output":
        return (price(rec, "output") or 0.0, rec.get("id", ""))
    if sort == "cache":
        return (
            price(rec, "cache_read")
            if price(rec, "cache_read") is not None
            else price(rec, "input") or 0.0,
            rec.get("id", ""),
        )
    if sort == "context":
        return (
            (rec.get("limit") or {}).get("context") or 0,
            rec.get("id", ""),
        )
    if sort == "out":
        return (
            (rec.get("limit") or {}).get("output") or 0,
            rec.get("id", ""),
        )
    raise ValueError(f"unknown sort: {sort}")


def render_table(records: list, args, w_in: float, w_cache: float, w_out: float) -> str:
    show_provider = args.provider == "all"
    show_blend = args.sort == "blend"

    headers = ["MODEL"]
    if show_provider:
        headers.append("PROVIDER")
    if show_blend:
        headers.append("BLEND")
    headers += ["$IN", "$OUT", "$CACHE", "CTX", "OUT", "CAPS"]

    rows = []
    for rec in records:
        limit = rec.get("limit") or {}
        caps = capabilities(rec)
        row = [
            model_label(rec, show_provider=False),
        ]
        if show_provider:
            row.append(rec.get("provider", "?"))
        if show_blend:
            row.append(fmt_money(blend_price(rec, w_in, w_cache, w_out)))
        row += [
            fmt_money(price(rec, "input")),
            fmt_money(price(rec, "output")),
            fmt_money(
                price(rec, "cache_read")
                if price(rec, "cache_read") is not None
                else price(rec, "input")
            ),
            fmt_tokens(limit.get("context")),
            fmt_tokens(limit.get("output")),
            " ".join(sorted(caps)),
        ]
        rows.append(row)

    # Column widths (right-align numbers, left-align text).
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt_row(row):
        cells = []
        for i, cell in enumerate(row):
            if i == 0:  # model id — left align
                cells.append(cell.ljust(widths[i]))
            else:
                cells.append(cell.rjust(widths[i]))
        return "  ".join(cells)

    lines = [fmt_row(headers), "  ".join("-" * w for w in widths)]
    lines += [fmt_row(r) for r in rows]
    return "\n".join(lines)


def render_info(rec: dict) -> str:
    limit = rec.get("limit") or {}
    cost = rec.get("cost") or {}
    mods = input_modalities(rec)

    lines = []
    lines.append(f"provider:     {rec.get('provider', '?')}")
    lines.append(f"id:           {rec.get('id', '?')}")
    lines.append(f"name:         {rec.get('name', '—')}")
    lines.append(f"description:  {rec.get('description', '—')}")
    lines.append(f"family:       {rec.get('family', '—')}")
    if rec.get("status"):
        lines.append(f"status:       {rec['status']}")
    lines.append(f"knowledge:    {rec.get('knowledge', '—')}")
    lines.append(f"released:     {rec.get('release_date', '—')}")

    lines.append("")
    lines.append("pricing (per 1M tokens):")
    for key, label in (
        ("input", "input "),
        ("output", "output"),
        ("cache_read", "cache read"),
        ("cache_write", "cache write"),
    ):
        if key in cost:
            lines.append(f"  {label:12} {fmt_money(cost[key])}")

    lines.append("")
    lines.append("limits (tokens):")
    lines.append(f"  context:     {limit.get('context', '—')}")
    if limit.get("input") is not None:
        lines.append(f"  input max:   {limit['input']}")
    lines.append(f"  output max:  {limit.get('output', '—')}")

    caps = sorted(capabilities(rec))
    lines.append("")
    lines.append(f"capabilities: {', '.join(caps) or '—'}")
    lines.append(
        f"modalities:   in=[{', '.join(mods) or '—'}] "
        f"out=[{', '.join((rec.get('modalities') or {}).get('output') or []) or '—'}]"
    )
    if rec.get("reasoning_options") is not None:
        lines.append(f"reasoning:    {json.dumps(rec['reasoning_options'])}")
    lines.append(f"temperature:  {rec.get('temperature', '—')}")
    lines.append(f"open weights: {rec.get('open_weights', '—')}")
    return "\n".join(lines)


# ── Filtering ─────────────────────────────────────────────────────────────────


def apply_filters(records: list, args) -> list:
    out = []
    for rec in records:
        if rec.get("status") and not args.include_deprecated:
            continue

        limit = rec.get("limit") or {}
        ctx = limit.get("context")
        out_lim = limit.get("output")

        if args.min_context and (ctx is None or ctx < args.min_context):
            continue
        if args.min_output and (out_lim is None or out_lim < args.min_output):
            continue

        for field, key in (("max_input", "input"), ("max_output", "output"), ("max_cache", "cache_read")):
            cap = getattr(args, field)
            if cap is None:
                continue
            val = price(rec, key)
            if key == "cache_read" and val is None:
                val = price(rec, "input")
            if val is not None and val > cap:
                break
        else:
            if args.capability:
                caps = capabilities(rec)
                if not all(c in caps for c in args.capability):
                    continue
            out.append(rec)
    return out


# ── Main ──────────────────────────────────────────────────────────────────────


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="opencode-models",
        description="Query LLM model pricing/capabilities from models.dev (default: OpenCode Go).",
    )
    p.add_argument(
        "-p", "--provider", default=DEFAULT_PROVIDER,
        help=f"provider id from models.dev, or 'all' (default: {DEFAULT_PROVIDER})",
    )
    p.add_argument(
        "-s", "--sort", default="blend",
        choices=["blend", "input", "output", "cache", "context", "out"],
        help="sort column (default: blend — a weighted $/1M mix)",
    )
    p.add_argument(
        "--blend", default="1,5,1",
        help="blend weights 'input,cache,output' for --sort blend (default: 1,5,1)",
    )
    p.add_argument("-n", "--top", type=int, default=None, help="show only the top N rows")
    p.add_argument("--min-context", type=int, default=None, help="min context window (tokens)")
    p.add_argument("--min-output", type=int, default=None, help="min output limit (tokens)")
    p.add_argument("--max-input", type=float, default=None, help="max $/1M input")
    p.add_argument("--max-output", type=float, default=None, help="max $/1M output")
    p.add_argument("--max-cache", type=float, default=None, help="max $/1M cache read")
    p.add_argument(
        "-c", "--capability", action="append", default=[],
        choices=sorted(CAP_GROUPS),
        help="require a capability (repeatable / comma-separated)",
    )
    p.add_argument("--include-deprecated", action="store_true", help="include deprecated models")
    p.add_argument("--refresh", action="store_true", help="bypass the on-disk cache")
    p.add_argument("--json", action="store_true", help="emit raw JSON of the filtered models")
    p.add_argument("-i", "--info", metavar="MODEL", default=None, help="full detail for one model id")
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    try:
        w_in, w_cache, w_out = (float(x) for x in args.blend.split(","))
    except ValueError:
        sys.stderr.write(f"error: --blend must be 'in,cache,out' (got '{args.blend}')\n")
        sys.exit(2)

    catalog = load_catalog(args.refresh)
    records = collect_models(catalog, args.provider)

    if args.info:
        rec = next((r for r in records if r.get("id") == args.info), None)
        if rec is None:
            sys.stderr.write(
                f"error: model '{args.info}' not found under provider '{args.provider}'.\n"
            )
            sys.exit(1)
        print(render_info(rec))
        return

    records = apply_filters(records, args)
    records.sort(key=lambda r: sort_key(r, args.sort, w_in, w_cache, w_out))

    if args.top is not None:
        records = records[: args.top]

    if args.json:
        print(json.dumps(records, indent=2))
        return

    if not records:
        print(f"no models match (provider={args.provider})")
        return

    show_provider = args.provider == "all"
    print(
        f"# {args.provider} — {len(records)} model(s)"
        + (
            f", sorted by blend {w_in:g}×in + {w_cache:g}×cache + {w_out:g}×out"
            if args.sort == "blend"
            else f", sorted by {args.sort}"
        )
    )
    print(render_table(records, args, w_in, w_cache, w_out))
    print(
        "\nprices are USD per 1M tokens (models.dev). "
        "CAPS: tools=function calling, vision=image, reason=thinking, "
        "struct=structured output, weights=open weights."
    )


if __name__ == "__main__":
    main()
