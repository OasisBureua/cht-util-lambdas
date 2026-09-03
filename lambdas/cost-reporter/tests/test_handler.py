from handler import handler


def test_stub_returns_not_implemented():
    result = handler({}, None)
    assert result["status"] == "stub"
    assert result["message"] == "not implemented"
