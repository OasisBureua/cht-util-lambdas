"""US federal holiday check in America/New_York."""

from __future__ import annotations

from datetime import date, datetime
from zoneinfo import ZoneInfo

import holidays

EASTERN = ZoneInfo("America/New_York")


def today_eastern() -> date:
    return datetime.now(EASTERN).date()


def is_us_federal_holiday(day: date | None = None) -> bool:
    check = day or today_eastern()
    return check in holidays.country_holidays("US")
