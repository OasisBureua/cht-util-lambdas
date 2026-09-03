"""RDS start/stop helpers with allowlist checks."""

from __future__ import annotations

import logging

import boto3
from botocore.exceptions import ClientError

from allowlist import AllowlistError, assert_dev_environment_tags, assert_on_allowlist, tags_to_dict

logger = logging.getLogger(__name__)


def _rds():
    return boto3.client("rds")


def _describe(db_id: str) -> dict | None:
    try:
        resp = _rds().describe_db_instances(DBInstanceIdentifier=db_id)
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "DBInstanceNotFound":
            return None
        raise
    instances = resp.get("DBInstances") or []
    return instances[0] if instances else None


def _db_tags(arn: str) -> dict[str, str]:
    resp = _rds().list_tags_for_resource(ResourceName=arn)
    return tags_to_dict(resp.get("TagList"))


def start_db(db_id: str, allowed: set[str], wait: bool = True) -> dict:
    assert_on_allowlist(db_id, allowed)
    instance = _describe(db_id)
    if not instance:
        logger.warning("RDS missing, skip: %s", db_id)
        return {"db": db_id, "status": "skipped_missing"}

    assert_dev_environment_tags(db_id, _db_tags(instance["DBInstanceArn"]))

    status = instance.get("DBInstanceStatus")
    if status == "available":
        return {"db": db_id, "status": "already_available"}
    if status == "starting":
        if wait:
            _wait_available(db_id)
        return {"db": db_id, "status": "starting"}

    try:
        _rds().start_db_instance(DBInstanceIdentifier=db_id)
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "InvalidDBInstanceState":
            logger.warning("RDS %s not startable (state=%s)", db_id, status)
            return {"db": db_id, "status": "invalid_state", "dbStatus": status}
        raise

    if wait:
        _wait_available(db_id)
    logger.info("Started RDS %s", db_id)
    return {"db": db_id, "status": "started"}


def stop_db(db_id: str, allowed: set[str]) -> dict:
    assert_on_allowlist(db_id, allowed)
    instance = _describe(db_id)
    if not instance:
        logger.warning("RDS missing, skip: %s", db_id)
        return {"db": db_id, "status": "skipped_missing"}

    assert_dev_environment_tags(db_id, _db_tags(instance["DBInstanceArn"]))

    status = instance.get("DBInstanceStatus")
    if status == "stopped":
        return {"db": db_id, "status": "already_stopped"}
    if status == "stopping":
        return {"db": db_id, "status": "stopping"}

    try:
        _rds().stop_db_instance(DBInstanceIdentifier=db_id)
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "InvalidDBInstanceState":
            logger.warning("RDS %s not stoppable (state=%s)", db_id, status)
            return {"db": db_id, "status": "invalid_state", "dbStatus": status}
        raise

    logger.info("Stopped RDS %s", db_id)
    return {"db": db_id, "status": "stopped"}


def _wait_available(db_id: str) -> None:
    try:
        _rds().get_waiter("db_instance_available").wait(
            DBInstanceIdentifier=db_id,
            WaiterConfig={"Delay": 15, "MaxAttempts": 40},
        )
    except Exception:
        logger.exception("Wait available failed for RDS %s", db_id)


def start_all(db_ids: list[str], wait: bool = True) -> list[dict]:
    allowed = set(db_ids)
    results: list[dict] = []
    for db_id in db_ids:
        try:
            results.append(start_db(db_id, allowed, wait=wait))
        except AllowlistError:
            logger.exception("Allowlist rejected RDS %s", db_id)
            raise
        except ClientError:
            logger.exception("RDS start error %s", db_id)
            results.append({"db": db_id, "status": "error"})
    return results


def stop_all(db_ids: list[str]) -> list[dict]:
    allowed = set(db_ids)
    results: list[dict] = []
    for db_id in db_ids:
        try:
            results.append(stop_db(db_id, allowed))
        except AllowlistError:
            logger.exception("Allowlist rejected RDS %s", db_id)
            raise
        except ClientError:
            logger.exception("RDS stop error %s", db_id)
            results.append({"db": db_id, "status": "error"})
    return results
