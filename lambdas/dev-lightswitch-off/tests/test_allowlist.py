from allowlist import is_denied_name


def test_denied_prod_names():
    assert is_denied_name("cht-platform-cluster")
    assert is_denied_name("contenthub-api")
    assert not is_denied_name("cht-dev-worker")
    assert not is_denied_name("contenthub-dev-db")
