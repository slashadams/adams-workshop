#!/usr/bin/env python3
"""
Hermes intel monitor for Adam.

Periodically checks:
  1. Hermes Agent version + ecosystem changes (GitHub releases, changelog)
  2. Hermes-using community work (web search, recent weeks)
  3. Adjacent tools and ideas (web search, topic-filtered)

Filters stream 3 aggressively to avoid listicle noise. Posts a weekly digest
to the Felix Intel Matrix room. Skips when nothing new.

Designed to run from cron (weekly). Idempotent on rerun — won't re-announce
items that have already been reported.

Setup:
  ~/.hermes/.env should already have everything needed; this script only needs
  access to the Matrix room ID (hardcoded below) and a way to do web searches.

Cron: 0 9 * * 1 (Mondays at 09:00).
"""

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# --- Config ------------------------------------------------------------------

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/root/.hermes"))
STATE_DIR = Path("/root/felix/intel-monitor")
STATE_FILE = STATE_DIR / "state.json"
LOG_FILE = STATE_DIR / "monitor.log"

MATRIX_ROOM = "!TZyazaMEV-pP3RvVJn-DTPRYOIvIz_yUUL0VaIqSkgU"  # Felix Intel
HERMES_GITHUB_ORG = "nousresearch"
HERMES_GITHUB_REPO = "hermes-agent"

# Matrix homeserver and credentials (read from ~/.hermes/.env, never echoed)
MATRIX_HOMESERVER = "http://10.0.100.39:6167"
MATRIX_USER = "@felix:10.0.100.39"

# Brave Search API for streams 2 and 3. Key read from ~/.hermes/.env at runtime.
# Uses the same key the Hermes agent's web_search tool uses.
BRAVE_API_BASE = "https://api.search.brave.com/res/v1/web/search"

# Topic filter for stream 3. All lowercase. A result matches if any of these
# appear in the title or summary. Tune this list over time based on what
# actually shows up in the digests.
STREAM3_TOPIC_KEYWORDS = [
    "agent memory",
    "memory architecture",
    "memory layer",
    "memory stack",
    "self-improvement",
    "self-evolution",
    "agent skill",
    "skill framework",
    "tool use",
    "tool-use",
    "tool calling",
    "agentic workflow",
    "agent orchestration",
    "prompt engineering",
    "context window",
    "ground truth",
    "long-term memory",
    "agent reflection",
]

# Listicle filter for stream 3. Titles matching these patterns get skipped
# unless the content is genuinely substantive.
LISTICLE_PATTERNS = [
    r"^\d+\s+(?:ways|patterns|tips|tricks|tools|things|secrets|lessons)",
    r"(?:will|that will) (?:change|transform|revolutionize|make)",
    r"you (?:need|must|should) (?:to know|know about)",
    r"(?:complete|ultimate|definitive) guide to",
    r"everything you need to know",
    r"i tried \d+",
    r"i tested \d+",
    r"(?:top|best) \d+",
    r"why (?:everyone|nobody) is (?:talking about|using)",
]

# --- Logging -----------------------------------------------------------------

def log(msg):
    ts = datetime.now(timezone.utc).isoformat()
    line = f"[{ts}] {msg}\n"
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a") as f:
        f.write(line)
    print(line, end="")

# --- State -------------------------------------------------------------------

def load_state():
    if not STATE_FILE.exists():
        return {"seen_keys": [], "last_run": None, "last_digest": None}
    try:
        return json.loads(STATE_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {"seen_keys": [], "last_run": None, "last_digest": None}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def is_seen(state, key):
    return key in state.get("seen_keys", [])

def mark_seen(state, key):
    seen = state.setdefault("seen_keys", [])
    if key not in seen:
        seen.append(key)
    # Keep last 500 seen keys to prevent unbounded growth
    if len(seen) > 500:
        state["seen_keys"] = seen[-500:]

# --- HTTP helper -------------------------------------------------------------

def http_get(url, headers=None, timeout=20):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")

def get_brave_api_key():
    """Read the Brave Search API key from ~/.hermes/.env."""
    env_file = HERMES_HOME / ".env"
    if not env_file.exists():
        return None
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if line.startswith("BRAVE_SEARCH_API_KEY="):
            return line.split("=", 1)[1].strip()
    return None

def brave_search(query, count=10):
    """Run a single Brave web search. Returns a list of {url, title, description} dicts."""
    api_key = get_brave_api_key()
    if not api_key:
        log(f"  Brave search error: BRAVE_SEARCH_API_KEY not in .env")
        return []
    params = urllib.parse.urlencode({"q": query, "count": count})
    url = f"{BRAVE_API_BASE}?{params}"
    try:
        req = urllib.request.Request(url, headers={
            "X-Subscription-Token": api_key,
            "Accept": "application/json",
        })
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        log(f"  Brave search error for query '{query}': {e}")
        return []
    results = []
    for r in data.get("web", {}).get("results", []):
        results.append({
            "url": r.get("url", ""),
            "title": r.get("title", ""),
            "description": r.get("description", ""),
        })
    return results

# --- Stream 1: Hermes Agent GitHub releases ---------------------------------

def fetch_github_releases():
    """Fetch the last 5 releases from the Hermes Agent GitHub repo."""
    url = f"https://api.github.com/repos/{HERMES_GITHUB_ORG}/{HERMES_GITHUB_REPO}/releases?per_page=5"
    try:
        data = json.loads(http_get(url, headers={"Accept": "application/vnd.github+json"}))
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        log(f"  Stream 1 ERROR: GitHub releases fetch failed: {e}")
        return []
    releases = []
    for r in data:
        if not isinstance(r, dict) or "tag_name" not in r:
            continue
        releases.append({
            "tag": r.get("tag_name", ""),
            "name": r.get("name") or r.get("tag_name", ""),
            "published_at": r.get("published_at", ""),
            "url": r.get("html_url", ""),
            "body": (r.get("body") or "")[:1500],  # truncate
            "prerelease": r.get("prerelease", False),
        })
    return releases

# --- Stream 2: Hermes-using community work ----------------------------------

def search_hermes_ecosystem():
    """Search for recent community work referencing Hermes by name.

    Uses Brave Search API. Returns up to 10 results.
    """
    queries = [
        '"hermes agent" nousresearch -site:github.com -site:reddit.com',
        '"hermes-agent" -site:github.com',
    ]
    results = []
    for q in queries:
        hits = brave_search(q, count=8)
        for r in hits:
            if not r.get("url") or "duckduckgo.com" in r["url"]:
                continue
            results.append({
                "url": r["url"],
                "title": (r.get("title") or "").strip(),
                "description": (r.get("description") or "").strip(),
            })
    # Dedupe by URL
    seen = set()
    unique = []
    for r in results:
        if r["url"] in seen:
            continue
        seen.add(r["url"])
        unique.append(r)
    return unique[:10]

# --- Stream 3: Adjacent tools/ideas, topic-filtered -------------------------

def search_adjacent():
    """Topic-filtered web search for adjacent tools and ideas. Uses Brave API."""
    all_queries = [
        "AI agent memory architecture patterns 2026",
        "AI agent self-improvement loops",
        "agent skill framework comparison",
        "long-term memory for LLM agents",
        "ground truth memory AI agents",
        "agent tool use patterns research",
        "agentic workflow orchestration patterns",
        "agent reflection and self-critique",
    ]
    week_number = datetime.now(timezone.utc).isocalendar()[1]
    offset = week_number % len(all_queries)
    queries = all_queries[offset:offset + 4]
    if len(queries) < 4:
        queries += all_queries[:4 - len(queries)]

    results = []
    for q in queries:
        hits = brave_search(q, count=8)
        for r in hits:
            if not r.get("url") or "duckduckgo.com" in r["url"]:
                continue
            title_clean = (r.get("title") or "").strip()
            desc_clean = (r.get("description") or "").strip()
            # Topic filter: must match at least one keyword in title or description
            haystack = (title_clean + " " + desc_clean).lower()
            if not any(kw in haystack for kw in STREAM3_TOPIC_KEYWORDS):
                continue
            # Listicle filter: skip pure listicle titles
            if any(re.search(p, title_clean.lower()) for p in LISTICLE_PATTERNS):
                continue
            results.append({
                "url": r["url"],
                "title": title_clean,
                "description": desc_clean,
                "query": q,
            })

    seen = set()
    unique = []
    for r in results:
        if r["url"] in seen:
            continue
        seen.add(r["url"])
        unique.append(r)
    return unique[:5]

# --- Summary generation ------------------------------------------------------

def generate_digest(stream1, stream1_new, stream2, stream2_new, stream3, stream3_new):
    """Build the digest text. Skips when nothing new."""
    total_new = len(stream1_new) + len(stream2_new) + len(stream3_new)

    if total_new == 0:
        # Show a quiet "nothing new" message
        return (
            "📡 Weekly intel — nothing new this week\n\n"
            f"Checked: {len(stream1)} releases, {len(stream2)} ecosystem hits, "
            f"{len(stream3)} adjacent ideas.\n"
            "Quiet week. Will check again next Monday."
        )

    parts = [f"📡 Weekly intel — {datetime.now(timezone.utc).strftime('%Y-%m-%d')}\n"]

    if stream1_new:
        parts.append("🔴 Hermes Agent changes (new):")
        for r in stream1_new:
            tag = r["tag"]
            name = r["name"] if r["name"] != tag else ""
            label = f"  • {tag}" + (f" — {name}" if name else "")
            if r.get("prerelease"):
                label += " (prerelease)"
            parts.append(label)
            if r["body"]:
                # First meaningful line of release notes
                first_line = next(
                    (l.strip() for l in r["body"].split("\n") if l.strip() and not l.strip().startswith("#")),
                    "",
                )
                if first_line and len(first_line) < 200:
                    parts.append(f"    {first_line}")
            if r["url"]:
                parts.append(f"    {r['url']}")
        parts.append("")

    if stream2_new:
        parts.append("🟡 Hermes in the wild (new since last week):")
        for r in stream2_new[:5]:
            parts.append(f"  • {r['title']}")
            parts.append(f"    {r['url']}")
        parts.append("")

    if stream3_new:
        parts.append("🔵 Adjacent ideas worth knowing (new):")
        for r in stream3_new[:5]:
            parts.append(f"  • {r['title']}")
            parts.append(f"    {r['url']}")
        parts.append("")

    parts.append(
        f"Filters: stream 3 requires topic match ({len(STREAM3_TOPIC_KEYWORDS)} keywords) "
        f"and excludes listicle titles."
    )
    return "\n".join(parts)

# --- Matrix delivery ---------------------------------------------------------

def post_to_matrix(message):
    """Post via Matrix Client-Server API directly.

    Why not `hermes send`: the hermes CLI has a bug with encrypted Conduit
    rooms — its bundled access token doesn't have the encryption keys. We
    get a fresh token per run instead, which has the keys for new rooms.
    Login is cheap (one HTTP call) and weekly cadence means it's fine.
    """
    env_file = HERMES_HOME / ".env"
    if not env_file.exists():
        log("  Matrix post error: ~/.hermes/.env not found")
        return False
    password = None
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if line.startswith("MATRIX_PASSWORD="):
            password = line.split("=", 1)[1].strip()
            break
    if not password:
        log("  Matrix post error: MATRIX_PASSWORD not in .env")
        return False

    try:
        # 1. Login to get a fresh access token
        login_body = json.dumps({
            "type": "m.login.password",
            "user": MATRIX_USER,
            "password": password,
        }).encode("utf-8")
        login_req = urllib.request.Request(
            f"{MATRIX_HOMESERVER}/_matrix/client/v3/login",
            data=login_body,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(login_req, timeout=15) as resp:
            login_data = json.loads(resp.read().decode("utf-8"))
        token = login_data.get("access_token")
        if not token:
            log("  Matrix post error: no access_token in login response")
            return False

        # 2. Send the message (Matrix uses PUT with a transaction ID, not POST)
        msg_body = json.dumps({
            "msgtype": "m.text",
            "body": message,
        }).encode("utf-8")
        txn_id = f"intel-{int(datetime.now(timezone.utc).timestamp() * 1000)}"
        send_req = urllib.request.Request(
            f"{MATRIX_HOMESERVER}/_matrix/client/v3/rooms/{MATRIX_ROOM}/send/m.room.message/{txn_id}",
            data=msg_body,
            method="PUT",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
        )
        with urllib.request.urlopen(send_req, timeout=15) as resp:
            send_data = json.loads(resp.read().decode("utf-8"))
        if "event_id" in send_data:
            return True
        log(f"  Matrix post error: no event_id in response: {send_data}")
        return False
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, KeyError) as e:
        log(f"  Matrix post error: {e}")
        return False

# --- Main --------------------------------------------------------------------

def main():
    log("Intel monitor starting")

    state = load_state()
    log(f"  state loaded: {len(state.get('seen_keys', []))} items previously seen")

    # Stream 1: GitHub releases
    log("  Stream 1: fetching Hermes Agent GitHub releases")
    stream1 = fetch_github_releases()
    stream1_new = []
    for r in stream1:
        key = f"github_release:{r['tag']}"
        if not is_seen(state, key):
            stream1_new.append(r)
            mark_seen(state, key)
    log(f"    {len(stream1)} releases found, {len(stream1_new)} new")

    # Stream 2: Ecosystem
    log("  Stream 2: searching Hermes-using community work")
    stream2 = search_hermes_ecosystem()
    stream2_new = []
    for r in stream2:
        key = f"ecosystem:{r['url']}"
        if not is_seen(state, key):
            stream2_new.append(r)
            mark_seen(state, key)
    log(f"    {len(stream2)} hits, {len(stream2_new)} new")

    # Stream 3: Adjacent (topic-filtered)
    log("  Stream 3: searching adjacent tools and ideas (topic-filtered)")
    stream3 = search_adjacent()
    stream3_new = []
    for r in stream3:
        key = f"adjacent:{r['url']}"
        if not is_seen(state, key):
            stream3_new.append(r)
            mark_seen(state, key)
    log(f"    {len(stream3)} topic-matching hits, {len(stream3_new)} new")

    # Generate digest
    digest = generate_digest(stream1, stream1_new, stream2, stream2_new, stream3, stream3_new)

    # Post
    log("  Posting digest to Matrix")
    if post_to_matrix(digest):
        log("  Digest posted successfully")
    else:
        log("  Digest post FAILED — message saved to log")
        log(f"  --- digest content ---\n{digest}\n  --- end digest ---")

    # Update state
    state["last_run"] = datetime.now(timezone.utc).isoformat()
    state["last_digest"] = {
        "stream1_new": len(stream1_new),
        "stream2_new": len(stream2_new),
        "stream3_new": len(stream3_new),
        "total_chars": len(digest),
    }
    save_state(state)
    log("  State saved")
    log("Intel monitor complete")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"FATAL: {e}")
        import traceback
        log(traceback.format_exc())
        sys.exit(1)
