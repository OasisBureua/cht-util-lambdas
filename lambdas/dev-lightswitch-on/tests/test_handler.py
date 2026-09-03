import json
from datetime import date
from unittest.mock import patch

from handler import handler


def _env(monkeypatch):
    monkeypatch.setenv(
        "ALLOWLIST_CLUSTERS",
        json.dumps(
            {
                "cht-dev-cluster": ["cht-dev-backend"],
                "contenthub-dev-cluster": ["contenthub-dev-api"],
            }
        ),
    )
    monkeypatch.setenv(
        "ALLOWLIST_DB_IDS",
        json.dumps(["cht-dev-db", "contenthub-dev-db"]),
    )
    monkeypatch.setenv("DESIRED_COUNT_ON", "1")
    monkeypatch.setenv("HEALTH_URLS", "")


@patch("handler.probe", return_value=[])
@patch("handler.start_all", return_value=[{"db": "cht-dev-db", "status": "started"}])
@patch("handler.scale_services", return_value=[{"service": "cht-dev-backend", "status": "updated"}])
@patch("handler.is_us_federal_holiday", return_value=False)
def test_on_runs(_holiday, scale, start, _health, monkeypatch):
    _env(monkeypatch)
    result = handler({"source": "eventbridge.scheduler"}, None)
    assert result["status"] == "ok"
    scale.assert_called_once()
    start.assert_called_once()
    assert scale.call_args.kwargs["desired"] == 1


@patch("handler.probe")
@patch("handler.start_all")
@patch("handler.scale_services")
@patch("handler.is_us_federal_holiday", return_value=True)
def test_on_skips_holiday(holiday, scale, start, probe, monkeypatch):
    _env(monkeypatch)
    result = handler({"source": "eventbridge.scheduler"}, None)
    assert result["status"] == "skipped_holiday"
    scale.assert_not_called()
    start.assert_not_called()
    probe.assert_not_called()
    holiday.assert_called()


@patch("handler.probe", return_value=[])
@patch("handler.start_all", return_value=[])
@patch("handler.scale_services", return_value=[])
@patch("handler.is_us_federal_holiday", return_value=True)
def test_manual_on_bypasses_holiday(_holiday, scale, start, _health, monkeypatch):
    _env(monkeypatch)
    result = handler({"source": "github.actions"}, None)
    assert result["status"] == "ok"
    scale.assert_called_once()
    start.assert_called_once()


def test_holiday_new_years():
    from holidays_check import is_us_federal_holiday

    assert is_us_federal_holiday(date(2026, 1, 1))
    assert not is_us_federal_holiday(date(2026, 1, 2))
