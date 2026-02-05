#!/usr/bin/env python3
"""Fetch Moltbook skill docs and store them under docs/.

Security:
- Fetch only from https://www.moltbook.com/*
- No API key needed.

Usage:
  python scripts/fetch_skill_docs.py
"""

from __future__ import annotations

import json
import time
from pathlib import Path
from urllib.parse import urlparse

import urllib.request

WORKSPACE = Path(__file__).resolve().parents[1]
DOCS_DIR = WORKSPACE / "docs"
STATE_PATH = WORKSPACE / "state" / "moltbook-state.json"

URLS = {
    "skill.skill.md": "https://www.moltbook.com/skill.md",
    "skill.heartbeat.md": "https://www.moltbook.com/heartbeat.md",
    "skill.messaging.md": "https://www.moltbook.com/messaging.md",
}


def _assert_allowed_url(url: str) -> None:
    p = urlparse(url)
    if p.scheme != "https":
        raise SystemExit(f"Refusing non-https URL: {url}")
    if p.netloc != "www.moltbook.com":
        raise SystemExit(f"Refusing non-allowed host (must be www.moltbook.com): {url}")


def fetch(url: str) -> str:
    _assert_allowed_url(url)
    req = urllib.request.Request(url, headers={"User-Agent": "openclaw-moltbook-agent/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    return data.decode("utf-8", errors="replace")


def main() -> None:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    for name, url in URLS.items():
        text = fetch(url)
        (DOCS_DIR / name).write_text(text, encoding="utf-8")

    state = {}
    if STATE_PATH.exists():
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    state["lastSkillFetchTs"] = int(time.time())
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("OK: fetched skill docs -> docs/")


if __name__ == "__main__":
    main()
