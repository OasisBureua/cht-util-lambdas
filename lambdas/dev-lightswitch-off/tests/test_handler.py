import json
from unittest.mock import patch

from handler import handler


def _env(monkeypatch):
    monkeypatch.setenv(
        "ALLOWLIST_CLUSTERS",
        json.dumps({"cht-dev-cluster": ["cht-dev-backend"]}),
    )
    monkeypatch.setenv("ALLOWLIST_DB_IDS", json.dumps(["cht-dev-db"]))


@patch("handler.stop_all", return_value=[{"db": "cht-dev-db", "status": "stopped"}])
@patch("handler.scale_services", return_value=[{"service": "cht-dev-backend", "status": "updated"}])
def test_off_scales_to_zero(scale, stop, monkeypatch):
    _env(monkeypatch)
    result = handler({"source": "eventbridge.scheduler"}, None)
    assert result["status"] == "ok"
    assert result["desiredCount"] == 0
    scale.assert_called_once()
    assert scale.call_args.kwargs["desired"] == 0
    stop.assert_called_once()


@patch("handler.stop_all", return_value=[])
@patch("handler.scale_services", return_value=[])
def test_off_runs_on_holiday_evening(scale, stop, monkeypatch):
    _env(monkeypatch)
    result = handler({"source": "eventbridge.scheduler"}, None)
    assert result["status"] == "ok"
    scale.assert_called_once()
    stop.assert_called_once()
