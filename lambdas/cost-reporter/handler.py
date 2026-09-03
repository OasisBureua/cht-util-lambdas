"""cht-dev-cost-reporter — stub (CUR / Cost Explorer later)."""

from __future__ import annotations

import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("cost-reporter stub; not implemented")
    return {
        "status": "stub",
        "message": "not implemented",
    }
