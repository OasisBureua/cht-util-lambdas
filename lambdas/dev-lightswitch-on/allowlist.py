"""Hard allowlist / deny rules for shared-account safety."""

from __future__ import annotations

import json
import os

PROD_DENY_EXACT = frozenset(
    {
        "contenthub-cluster",
        "contenthub-api",
    }
)

ALLOWED_ENV_TAGS = frozenset({"dev", "development"})


class AllowlistError(Exception):
    """Raised when a target is not on the allowlist or matches a deny rule."""


def load_clusters() -> dict[str, list[str]]:
    raw = os.environ.get("ALLOWLIST_CLUSTERS", "{}")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise AllowlistError("ALLOWLIST_CLUSTERS must be a JSON object")
    return {str(cluster): [str(s) for s in services] for cluster, services in data.items()}


def load_db_ids() -> list[str]:
    raw = os.environ.get("ALLOWLIST_DB_IDS", "[]")
    data = json.loads(raw)
    if not isinstance(data, list):
        raise AllowlistError("ALLOWLIST_DB_IDS must be a JSON array")
    return [str(i) for i in data]


def desired_count_on() -> int:
    return int(os.environ.get("DESIRED_COUNT_ON", "1"))


def is_denied_name(name: str) -> bool:
    lowered = name.lower()
    if "cht-platform" in lowered:
        return True
    if "-prod-" in lowered or lowered.endswith("-prod") or lowered.startswith("prod-"):
        return True
    if lowered in PROD_DENY_EXACT:
        return True
    if "-dev-" not in lowered:
        return True
    return False


def assert_allowed_name(name: str) -> None:
    if is_denied_name(name):
        raise AllowlistError(f"denied name: {name}")


def assert_on_allowlist(name: str, allowed: set[str]) -> None:
    assert_allowed_name(name)
    if name not in allowed:
        raise AllowlistError(f"not on allowlist: {name}")


def tags_to_dict(tag_list: list[dict] | None) -> dict[str, str]:
    out: dict[str, str] = {}
    for tag in tag_list or []:
        key = tag.get("Key") or tag.get("key")
        value = tag.get("Value") or tag.get("value")
        if key is not None and value is not None:
            out[str(key)] = str(value)
    return out


def assert_dev_environment_tags(name: str, tags: dict[str, str]) -> None:
    env = tags.get("Environment") or tags.get("environment")
    if env not in ALLOWED_ENV_TAGS:
        raise AllowlistError(
            f"{name} missing Environment=dev|development (got {env!r})"
        )
