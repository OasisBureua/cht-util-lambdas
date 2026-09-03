"""Optional HTTP health probes (log-only)."""

from __future__ import annotations

import logging
import os
import urllib.error
import urllib.request

logger = logging.getLogger(__name__)


def health_urls() -> list[str]:
    raw = os.environ.get("HEALTH_URLS", "")
    return [part.strip() for part in raw.split(",") if part.strip()]


def probe(urls: list[str] | None = None) -> list[dict]:
    results: list[dict] = []
    for url in urls if urls is not None else health_urls():
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                results.append({"url": url, "status": resp.status})
                logger.info("Health %s -> %s", url, resp.status)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            logger.warning("Health %s failed: %s", url, exc)
            results.append({"url": url, "status": "error", "error": str(exc)})
    return results
