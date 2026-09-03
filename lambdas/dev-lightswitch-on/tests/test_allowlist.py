import json

import pytest

from allowlist import (
    AllowlistError,
    assert_allowed_name,
    assert_dev_environment_tags,
    assert_on_allowlist,
    is_denied_name,
    load_clusters,
    load_db_ids,
)


def test_denied_prod_and_platform_names():
    assert is_denied_name("cht-platform-cluster")
    assert is_denied_name("cht-platform-backend")
    assert is_denied_name("contenthub-cluster")
    assert is_denied_name("contenthub-api")
    assert is_denied_name("cht-prod-db")
    assert is_denied_name("something-without-dev")


def test_allowed_dev_names():
    assert not is_denied_name("cht-dev-cluster")
    assert not is_denied_name("cht-dev-backend")
    assert not is_denied_name("contenthub-dev-cluster")
    assert not is_denied_name("contenthub-dev-api")
    assert not is_denied_name("cht-dev-companion-db")


def test_assert_on_allowlist(monkeypatch):
    monkeypatch.setenv(
        "ALLOWLIST_CLUSTERS",
        json.dumps({"cht-dev-cluster": ["cht-dev-backend"]}),
    )
    clusters = load_clusters()
    assert_on_allowlist("cht-dev-backend", set(clusters["cht-dev-cluster"]))
    with pytest.raises(AllowlistError):
        assert_on_allowlist("cht-dev-worker", set(clusters["cht-dev-cluster"]))
    with pytest.raises(AllowlistError):
        assert_allowed_name("cht-platform-backend")


def test_load_db_ids(monkeypatch):
    monkeypatch.setenv(
        "ALLOWLIST_DB_IDS",
        json.dumps(["cht-dev-db", "contenthub-dev-db"]),
    )
    assert load_db_ids() == ["cht-dev-db", "contenthub-dev-db"]


def test_environment_tags():
    assert_dev_environment_tags("cht-dev-db", {"Environment": "dev"})
    assert_dev_environment_tags("x", {"Environment": "development"})
    with pytest.raises(AllowlistError):
        assert_dev_environment_tags("cht-dev-db", {})
    with pytest.raises(AllowlistError):
        assert_dev_environment_tags("cht-dev-db", {"Environment": "platform"})
