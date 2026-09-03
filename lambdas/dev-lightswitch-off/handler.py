"""cht-dev-lightswitch-off — scale allowlisted dev ECS/RDS down."""

from __future__ import annotations

import json
import logging
import os

from allowlist import load_clusters, load_db_ids
from ecs_actions import scale_services
from rds_actions import stop_all

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    event = event or {}
    source = str(event.get("source") or "eventbridge.scheduler")
    logger.info("lightswitch-off source=%s event=%s", source, json.dumps(event))

    clusters = load_clusters()
    db_ids = load_db_ids()

    ecs_results = scale_services(clusters, desired=0, wait=False)
    rds_results = stop_all(db_ids)

    result = {
        "status": "ok",
        "source": source,
        "desiredCount": 0,
        "ecs": ecs_results,
        "rds": rds_results,
        "region": os.environ.get("AWS_REGION", "us-east-1"),
    }
    logger.info("lightswitch-off done: %s", json.dumps(result))
    return result
