"""cht-dev-lightswitch-off — scale allowlisted dev ECS services to zero.

RDS instances are left running.
"""

from __future__ import annotations

import json
import logging
import os

from allowlist import load_clusters
from ecs_actions import scale_services

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    event = event or {}
    source = str(event.get("source") or "eventbridge.scheduler")
    logger.info("lightswitch-off source=%s event=%s", source, json.dumps(event))

    clusters = load_clusters()

    ecs_results = scale_services(clusters, desired=0, wait=False)

    result = {
        "status": "ok",
        "source": source,
        "desiredCount": 0,
        "ecs": ecs_results,
        "region": os.environ.get("AWS_REGION", "us-east-1"),
    }
    logger.info("lightswitch-off done: %s", json.dumps(result))
    return result
