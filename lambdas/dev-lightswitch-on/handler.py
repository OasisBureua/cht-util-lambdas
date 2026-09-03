"""cht-dev-lightswitch-on — scale allowlisted dev ECS/RDS up."""

from __future__ import annotations

import json
import logging
import os

from allowlist import load_clusters, load_db_ids, desired_count_on
from ecs_actions import scale_services
from health import probe
from holidays_check import is_us_federal_holiday
from rds_actions import start_all

logger = logging.getLogger()
logger.setLevel(logging.INFO)

MANUAL_SOURCES = frozenset({"github.actions"})


def handler(event, context):
    event = event or {}
    source = str(event.get("source") or "eventbridge.scheduler")
    logger.info("lightswitch-on source=%s event=%s", source, json.dumps(event))

    if source not in MANUAL_SOURCES and is_us_federal_holiday():
        logger.info("US federal holiday — skipping scheduled on")
        return {"status": "skipped_holiday", "source": source}

    clusters = load_clusters()
    db_ids = load_db_ids()
    desired = desired_count_on()

    ecs_results = scale_services(clusters, desired=desired, wait=True)
    rds_results = start_all(db_ids, wait=True)
    health_results = probe()

    result = {
        "status": "ok",
        "source": source,
        "desiredCount": desired,
        "ecs": ecs_results,
        "rds": rds_results,
        "health": health_results,
        "region": os.environ.get("AWS_REGION", "us-east-1"),
    }
    logger.info("lightswitch-on done: %s", json.dumps(result))
    return result
