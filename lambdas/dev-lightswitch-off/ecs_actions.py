"""ECS UpdateService helpers with allowlist checks."""

from __future__ import annotations

import logging

import boto3
from botocore.exceptions import ClientError

from allowlist import AllowlistError, assert_dev_environment_tags, assert_on_allowlist, tags_to_dict

logger = logging.getLogger(__name__)


def _ecs():
    return boto3.client("ecs")


def _service_arn(cluster: str, service: str) -> str | None:
    resp = _ecs().describe_services(cluster=cluster, services=[service])
    services = resp.get("services") or []
    if not services:
        return None
    svc = services[0]
    if svc.get("status") == "INACTIVE":
        return None
    return svc.get("serviceArn")


def _cluster_arn(cluster: str) -> str | None:
    resp = _ecs().describe_clusters(clusters=[cluster])
    clusters = resp.get("clusters") or []
    if not clusters or clusters[0].get("status") != "ACTIVE":
        return None
    return clusters[0].get("clusterArn")


def _resource_tags(arn: str) -> dict[str, str]:
    resp = _ecs().list_tags_for_resource(resourceArn=arn)
    return tags_to_dict(resp.get("tags"))


def set_desired_count(
    cluster: str,
    service: str,
    desired: int,
    allowed_clusters: set[str],
    allowed_services: set[str],
) -> dict:
    assert_on_allowlist(cluster, allowed_clusters)
    assert_on_allowlist(service, allowed_services)

    cluster_arn = _cluster_arn(cluster)
    if not cluster_arn:
        logger.warning("ECS cluster missing, skip: %s", cluster)
        return {"cluster": cluster, "service": service, "status": "skipped_missing"}

    assert_dev_environment_tags(cluster, _resource_tags(cluster_arn))

    service_arn = _service_arn(cluster, service)
    if not service_arn:
        logger.warning("ECS service missing, skip: %s/%s", cluster, service)
        return {
            "cluster": cluster,
            "service": service,
            "status": "skipped_missing",
        }

    assert_dev_environment_tags(service, _resource_tags(service_arn))

    _ecs().update_service(cluster=cluster, service=service, desiredCount=desired)
    logger.info("Updated %s/%s desiredCount=%s", cluster, service, desired)
    return {
        "cluster": cluster,
        "service": service,
        "status": "updated",
        "desiredCount": desired,
    }


def wait_stable(cluster: str, service: str) -> None:
    try:
        _ecs().get_waiter("services_stable").wait(
            cluster=cluster,
            services=[service],
            WaiterConfig={"Delay": 15, "MaxAttempts": 20},
        )
    except ClientError:
        logger.exception("Wait services_stable failed for %s/%s", cluster, service)
    except Exception:
        logger.exception("Wait services_stable failed for %s/%s", cluster, service)


def scale_services(
    clusters: dict[str, list[str]],
    desired: int,
    wait: bool = True,
) -> list[dict]:
    allowed_clusters = set(clusters)
    results: list[dict] = []
    for cluster, services in clusters.items():
        allowed_services = set(services)
        for service in services:
            try:
                result = set_desired_count(
                    cluster, service, desired, allowed_clusters, allowed_services
                )
                if wait and result.get("status") == "updated" and desired > 0:
                    wait_stable(cluster, service)
                results.append(result)
            except AllowlistError:
                logger.exception("Allowlist rejected %s/%s", cluster, service)
                raise
            except ClientError:
                logger.exception("ECS error %s/%s", cluster, service)
                results.append(
                    {
                        "cluster": cluster,
                        "service": service,
                        "status": "error",
                    }
                )
    return results
