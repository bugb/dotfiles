#!/usr/bin/env python3
"""Claude Code status line.

Reads the status-line JSON payload on stdin and prints one line:

    branch  dir  model·effort  weather  tokens  ctx  cost  quota

Branch is red on the default branch (master/main) and green anywhere else.

Design notes, because this runs on every status-line refresh:
  - the weather is served from a cache file and refreshed in a detached
    background process, so a slow network never blocks the prompt
  - token totals are accumulated incrementally: each run reads only the bytes
    appended to the transcript since the previous run
Everything is stdlib, and every section degrades to "omitted" rather than
raising, so a broken piece can never take out the whole status line.
"""

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "claude-statusline"
WEATHER_LOCATION = os.environ.get("CLAUDE_STATUSLINE_WEATHER", "Hanoi")
WEATHER_TTL = 30 * 60  # seconds
DEFAULT_BRANCHES = {"master", "main"}

R = "\033[0m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
MAGENTA = "\033[35m"
CYAN = "\033[36m"
DIM = "\033[2m"
BOLD = "\033[1m"


def human(n):
    """1234 -> 1.2k, 1234567 -> 1.2M."""
    n = float(n or 0)
    for limit, suffix in ((1e9, "G"), (1e6, "M"), (1e3, "k")):
        if abs(n) >= limit:
            return f"{n / limit:.1f}{suffix}"
    return str(int(n))


def bytes_h(n):
    """Byte count as a short human string: 1536 -> 1.5K, 2e12 -> 1.8T."""
    n = float(n or 0)
    for limit, suffix in ((1 << 40, "T"), (1 << 30, "G"), (1 << 20, "M"), (1 << 10, "K")):
        if n >= limit:
            scaled = n / limit
            return f"{scaled:.0f}{suffix}" if scaled >= 10 else f"{scaled:.1f}{suffix}"
    return f"{int(n)}B"


def sh(args, cwd=None, timeout=1.0):
    """Run a command, returning stripped stdout or None. Never raises."""
    try:
        out = subprocess.run(
            args, cwd=cwd, capture_output=True, text=True, timeout=timeout
        )
    except Exception:
        return None
    return out.stdout.strip() if out.returncode == 0 else None


# ----------------------------------------------------------------- sections --


def git_head(cwd):
    """Current branch, or a short sha when detached. None outside a repo.

    Reads .git/HEAD rather than shelling out: `git rev-parse` measures ~15ms
    here against ~0.04ms for the file read, and this runs on every refresh.
    Falls back to git for the layouts a plain read cannot resolve — worktrees
    and submodules, where .git is a file pointing elsewhere.
    """
    try:
        here = Path(cwd).resolve()
        for directory in (here, *here.parents):
            dot = directory / ".git"
            if not dot.exists():
                continue
            if dot.is_dir():
                head = (dot / "HEAD").read_text().strip()
                if head.startswith("ref: refs/heads/"):
                    return head[len("ref: refs/heads/"):]
                return head[:7]  # detached: raw sha
            break  # .git is a file: a worktree or submodule, let git resolve it
    except Exception:
        pass

    branch = sh(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=cwd)
    if branch == "HEAD":
        return (sh(["git", "rev-parse", "--short", "HEAD"], cwd=cwd) or "detached")[:7]
    return branch


def seg_git(cwd):
    """Branch name, red on the default branch and green otherwise."""
    branch = git_head(cwd)
    if not branch:
        return None

    # A raw sha rather than a branch name means detached HEAD.
    if len(branch) == 7 and all(c in "0123456789abcdef" for c in branch):
        return f"{YELLOW}⚠ {branch}{R}"

    # Colour AND a glyph. The active theme here is a daltonized one, and red vs
    # green is the pair that reads worst with a colour vision deficiency, so the
    # marker carries the same meaning on its own: a flag on the default branch,
    # a branch symbol anywhere else.
    on_default = branch in DEFAULT_BRANCHES
    colour = RED if on_default else GREEN
    mark = "⚑" if on_default else "⎇"
    branch = f"{mark} {branch}"

    # A cheap dirty check: --quiet exits 1 when the worktree has changes.
    dirty = ""
    try:
        rc = subprocess.run(
            ["git", "diff", "--quiet", "--ignore-submodules", "HEAD"],
            cwd=cwd,
            capture_output=True,
            timeout=1.0,
        ).returncode
        if rc == 1:
            dirty = f"{YELLOW}*{R}"
    except Exception:
        pass

    return f"{colour}{branch}{R}{dirty}"


def live_cwd(data):
    """The directory to report on.

    The status-line payload carries the *session* directory, which does not
    follow a `cd`. Claude Code emits a CwdChanged hook when the working
    directory actually moves, but only when such a hook is registered — so the
    hook (see --record-cwd below) writes the new path here and this prefers it.
    Falls back to the payload when no hook has fired yet.
    """
    session = data.get("session_id")
    payload_cwd = data.get("workspace", {}).get("current_dir") or data.get("cwd") or ""

    if session:
        try:
            recorded = (CACHE / f"cwd-{session}").read_text().strip()
            if recorded and os.path.isdir(recorded):
                return recorded
        except Exception:
            pass
    return payload_cwd


def install_settings():
    """Wire this script into ~/.claude/settings.json. Idempotent.

    settings.json cannot simply be symlinked out of the repo: it also holds
    machine-local preferences and anything Claude Code writes itself. So the two
    keys this status line needs are merged in, leaving everything else alone.
    """
    settings_path = Path.home() / ".claude" / "settings.json"
    script = "$HOME/.claude/statusline.py"
    status_cmd = f'python3 "{script}"'
    hook_cmd = f'python3 "{script}" --record-cwd 2>/dev/null || true'

    try:
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        original = settings_path.read_text() if settings_path.exists() else "{}"
        data = json.loads(original or "{}")
    except Exception as exc:
        print(f"cannot read {settings_path}: {exc}", file=sys.stderr)
        return 1
    if not isinstance(data, dict):
        print(f"{settings_path} is not a JSON object; refusing to touch it", file=sys.stderr)
        return 1

    before = json.dumps(data, sort_keys=True)

    data["statusLine"] = {
        "type": "command",
        "command": status_cmd,
        "refreshInterval": 60,
    }

    # Append the cwd hook only if an equivalent one is not already present.
    hooks = data.setdefault("hooks", {})
    if isinstance(hooks, dict):
        entries = hooks.setdefault("CwdChanged", [])
        if isinstance(entries, list):
            already = any(
                "--record-cwd" in (h.get("command") or "")
                for entry in entries
                if isinstance(entry, dict)
                for h in (entry.get("hooks") or [])
                if isinstance(h, dict)
            )
            if not already:
                entries.append(
                    {"hooks": [{"type": "command", "command": hook_cmd, "timeout": 5}]}
                )

    if json.dumps(data, sort_keys=True) == before:
        print(f"settings already wired: {settings_path}")
        return 0

    # Back up whatever was there before rewriting it.
    if settings_path.exists():
        n, backup = 0, settings_path.with_suffix(".json.backup")
        while backup.exists():
            n += 1
            backup = settings_path.with_suffix(f".json.backup.{n}")
        backup.write_text(original)
        print(f"backed up previous settings to {backup.name}")

    tmp = settings_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    tmp.replace(settings_path)
    print(f"wired status line into {settings_path}")
    return 0


def record_cwd():
    """CwdChanged hook entry point: persist new_cwd for the status line."""
    try:
        data = json.loads(sys.stdin.read() or "{}")
        session = data.get("session_id")
        new = data.get("new_cwd") or data.get("cwd")
        if session and new:
            CACHE.mkdir(parents=True, exist_ok=True)
            tmp = CACHE / f"cwd-{session}.tmp"
            tmp.write_text(new)
            tmp.replace(CACHE / f"cwd-{session}")
    except Exception:
        pass
    return 0


def seg_dir(cwd):
    if not cwd:
        return None
    home = str(Path.home())
    shown = "~" + cwd[len(home):] if cwd.startswith(home) else cwd
    # Only the last two components, to keep the line short.
    parts = [p for p in shown.split(os.sep) if p]
    if len(parts) > 2:
        shown = os.sep.join(parts[-2:])
    return f"{BLUE}{shown}{R}"


def seg_model(data):
    """Model, plus effort level and a marker when thinking is off."""
    model = data.get("model", {}).get("display_name")
    if not model:
        return None
    out = f"{MAGENTA}{model}{R}"

    effort = (data.get("effort") or {}).get("level")
    if effort:
        out += f"{DIM}·{effort}{R}"
    if data.get("thinking", {}).get("enabled") is False:
        out += f"{DIM}·nothink{R}"
    if data.get("fast_mode"):
        out += f"{YELLOW}·fast{R}"
    return out


def seg_weather():
    """Cached weather. Refreshed by a detached child; never blocks."""
    cache = CACHE / f"weather-{WEATHER_LOCATION.lower().replace(' ', '-')}.txt"
    text, age = None, None
    try:
        text = cache.read_text().strip()
        age = time.time() - cache.stat().st_mtime
    except Exception:
        pass

    if age is None or age > WEATHER_TTL:
        _refresh_weather(cache)

    if not text:
        return None
    return f"{CYAN}{text}{R}"


def _refresh_weather(cache):
    """Spawn a detached curl that rewrites the cache, then return immediately."""
    lock = cache.with_suffix(".lock")
    try:
        # Don't pile up fetches if one is already in flight or just failed.
        if lock.exists() and time.time() - lock.stat().st_mtime < 120:
            return
        CACHE.mkdir(parents=True, exist_ok=True)
        lock.touch()
    except Exception:
        return

    url = f"https://wttr.in/{WEATHER_LOCATION}?format=%c+%t&m"
    script = (
        f'out=$(curl -sS --max-time 15 {url!r} 2>/dev/null); '
        f'case "$out" in *Unknown*|"") ;; *) printf "%s" "$out" > {str(cache)!r} ;; esac; '
        f'rm -f {str(lock)!r}'
    )
    try:
        subprocess.Popen(
            ["/bin/sh", "-c", script],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception:
        try:
            lock.unlink()
        except Exception:
            pass


def mem_info():
    """(available_bytes, total_bytes), or None.

    Total comes from sysconf on both platforms, so no subprocess. "Available"
    means reclaimable-without-swapping on both: Linux reports MemAvailable
    directly, and the macOS equivalent is free + inactive + speculative +
    purgeable. Using the same definition on both keeps the number comparable
    across machines.
    """
    total = 0
    try:
        total = os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE")
    except Exception:
        pass

    # Linux: authoritative and cheap.
    try:
        with open("/proc/meminfo") as fh:
            vals = {}
            for line in fh:
                key, _, rest = line.partition(":")
                parts = rest.split()
                if parts:
                    vals[key] = int(parts[0]) * 1024
        if vals.get("MemTotal"):
            avail = vals.get("MemAvailable")
            if avail is None:
                avail = vals.get("MemFree", 0) + vals.get("Cached", 0)
            return avail, vals["MemTotal"]
    except Exception:
        pass

    # macOS: vm_stat is the only source for the page breakdown.
    out = sh(["vm_stat"])
    if not out or not total:
        return None
    try:
        page = 4096
        head = out.splitlines()[0]
        if "page size of" in head:
            page = int(head.split("page size of")[1].split()[0])

        pages = {}
        for line in out.splitlines()[1:]:
            key, _, rest = line.partition(":")
            digits = rest.strip().rstrip(".").strip()
            if digits.isdigit():
                pages[key.strip()] = int(digits)

        avail = page * sum(
            pages.get(k, 0)
            for k in ("Pages free", "Pages inactive", "Pages speculative", "Pages purgeable")
        )
        return avail, total
    except Exception:
        return None


def seg_ram():
    info = mem_info()
    if not info:
        return None
    avail, total = info
    if not total:
        return None
    used_pct = (total - avail) / total * 100
    colour = GREEN if used_pct < 75 else (YELLOW if used_pct < 90 else RED)
    return f"{DIM}ram{R} {colour}{bytes_h(avail)}{R}{DIM}/{bytes_h(total)}{R}"


def seg_cpu():
    """Load average over the last minute, as a share of available cores.

    This is run-queue length, not instantaneous utilisation — measuring that
    properly needs two samples separated in time, which a status line cannot
    afford. Over 100% means tasks are queueing for a core.
    """
    try:
        load1 = os.getloadavg()[0]
        cores = os.cpu_count() or 1
    except Exception:
        return None
    pct = round(load1 / cores * 100)
    colour = GREEN if pct < 60 else (YELLOW if pct < 100 else RED)
    return f"{DIM}cpu{R} {colour}{pct}%{R}"


def seg_disk(cwd):
    """Free space on the volume holding the working directory.

    Uses the working directory rather than / so an external drive or a separate
    data volume reports itself. Shown as free/total; the colour tracks how full
    the volume is.

    Note for macOS: on APFS the free figure is the shared container's, which is
    why `df /` can print a much lower "capacity" than the fullness implied here
    — that column describes the sealed system volume, not real usage.
    """
    target = cwd if cwd and os.path.isdir(cwd) else os.path.expanduser("~")
    try:
        usage = shutil.disk_usage(target)
    except Exception:
        return None
    if not usage.total:
        return None

    used_pct = usage.used / usage.total * 100
    colour = GREEN if used_pct < 75 else (YELLOW if used_pct < 90 else RED)
    return f"{DIM}disk{R} {colour}{bytes_h(usage.free)}{R}{DIM}/{bytes_h(usage.total)}{R}"


def seg_tokens(data):
    """Cumulative input/output tokens for this session.

    The transcript is append-only JSONL, so only the bytes added since the last
    render are parsed. State is keyed by session id; if the file shrinks (a
    rewrite or a new session reusing the path) the counters restart.
    """
    path = data.get("transcript_path")
    session = data.get("session_id") or "unknown"
    if not path or not os.path.exists(path):
        return None

    state_file = CACHE / f"tokens-{session}.json"
    fresh = {"offset": 0, "in": 0, "out": 0, "ids": []}
    state = dict(fresh)
    try:
        state.update(json.loads(state_file.read_text()))
    except Exception:
        pass
    seen = set(state.get("ids") or [])

    try:
        size = os.path.getsize(path)
        if size < state["offset"]:  # truncated or replaced
            state, seen = dict(fresh), set()

        if size > state["offset"]:
            with open(path, "r", errors="replace") as fh:
                fh.seek(state["offset"])
                chunk = fh.read()
                # Only count through the last complete line; a partial trailing
                # line would be re-read (and double counted) on the next pass.
                cut = chunk.rfind("\n")
                if cut >= 0:
                    for line in chunk[:cut].splitlines():
                        got = _usage_of(line)
                        if not got:
                            continue
                        key, u = got
                        # The transcript repeats a message's usage record on
                        # every rewrite — up to six times for one message — and
                        # the copies are identical. Counting each occurrence
                        # inflates the total by roughly half, so count an id once.
                        if key is not None:
                            if key in seen:
                                continue
                            seen.add(key)
                        state["in"] += (
                            (u.get("input_tokens") or 0)
                            + (u.get("cache_creation_input_tokens") or 0)
                            + (u.get("cache_read_input_tokens") or 0)
                        )
                        state["out"] += u.get("output_tokens") or 0
                    state["offset"] += len(chunk[: cut + 1].encode("utf-8", "replace"))
        state["ids"] = list(seen)

        CACHE.mkdir(parents=True, exist_ok=True)
        tmp = state_file.with_suffix(".tmp")
        tmp.write_text(json.dumps(state))
        tmp.replace(state_file)
    except Exception:
        pass

    if not state["in"] and not state["out"]:
        return None
    return f"{DIM}↑{R}{human(state['in'])} {DIM}↓{R}{human(state['out'])}"


def _usage_of(line):
    """(dedupe_key, usage_dict) for a transcript line, or None."""
    try:
        rec = json.loads(line)
    except Exception:
        return None
    msg = rec.get("message")
    if isinstance(msg, dict):
        u = msg.get("usage")
        if isinstance(u, dict):
            key = msg.get("id") or rec.get("requestId") or rec.get("uuid")
            return key, u
    return None


def seg_context(data):
    """Context window fill, coloured once it starts to matter."""
    cw = data.get("context_window") or {}
    used = cw.get("used_percentage")
    if used is None:
        return None
    used = round(float(used))
    colour = GREEN if used < 50 else (YELLOW if used < 80 else RED)
    return f"{DIM}ctx{R} {colour}{used}%{R}"


def seg_cost(data):
    cost = (data.get("cost") or {}).get("total_cost_usd")
    if cost is None:
        return None
    return f"{DIM}${R}{float(cost):.2f}"


def seg_quota(data):
    """Plan usage: how much of the 5-hour and 7-day allowance is spent.

    This is what Claude Code exposes; there is no account credit balance in the
    payload. Absent on plans that do not report rate limits.
    """
    rl = data.get("rate_limits") or {}
    bits = []
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        window = rl.get(key) or {}
        pct = window.get("used_percentage")
        if pct is None:
            continue
        pct = round(float(pct))
        colour = GREEN if pct < 50 else (YELLOW if pct < 85 else RED)
        bits.append(f"{DIM}{label}{R} {colour}{pct}%{R}")
    return " ".join(bits) if bits else None


# --------------------------------------------------------------------- main --


def main():
    if "--record-cwd" in sys.argv:
        return record_cwd()
    if "--install-settings" in sys.argv:
        return install_settings()

    try:
        data = json.loads(sys.stdin.read() or "{}")
    except Exception:
        data = {}

    cwd = live_cwd(data) or os.getcwd()

    sections = []
    for fn in (
        lambda: seg_git(cwd),
        lambda: seg_dir(cwd),
        lambda: seg_model(data),
        seg_weather,
        seg_cpu,
        seg_ram,
        lambda: seg_disk(cwd),
        lambda: seg_tokens(data),
        lambda: seg_context(data),
        lambda: seg_cost(data),
        lambda: seg_quota(data),
    ):
        try:
            value = fn()
        except Exception:
            value = None
        if value:
            sections.append(value)

    sys.stdout.write(f" {DIM}│{R} ".join(sections))
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
