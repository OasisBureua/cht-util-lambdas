#!/usr/bin/env bash
# Build a JSON map of lambda directory name → image URI for Terraform.
# Uses newly built tags from images.env (NAME=tag lines) when present,
# otherwise the live Lambda ImageUri, otherwise :dev-latest.
#
# Usage: ci-lambda-image-map.sh <ecr_registry> <aws_region> [images.env]
set -euo pipefail

REGISTRY="${1:?registry required}"
REGION="${2:-us-east-1}"
IMAGES_ENV="${3:-}"

declare -A NEW_TAGS=()
if [ -n "$IMAGES_ENV" ] && [ -f "$IMAGES_ENV" ]; then
  while IFS='=' read -r name tag; do
    [ -n "${name:-}" ] || continue
    NEW_TAGS["$name"]="$tag"
  done < "$IMAGES_ENV"
fi

items=()
for dockerfile in lambdas/*/Dockerfile; do
  name="$(basename "$(dirname "$dockerfile")")"
  repo="cht-dev-${name}"
  fn="cht-dev-${name}"
  if [ -n "${NEW_TAGS[$name]:-}" ]; then
    uri="${REGISTRY}/${repo}:${NEW_TAGS[$name]}"
  else
    uri="$(aws lambda get-function \
      --function-name "$fn" \
      --region "$REGION" \
      --query 'Code.ImageUri' \
      --output text 2>/dev/null || true)"
    if [ -z "$uri" ] || [ "$uri" = "None" ]; then
      uri="${REGISTRY}/${repo}:dev-latest"
    fi
  fi
  items+=("$(jq -nc --arg k "$name" --arg v "$uri" '{key:$k,value:$v}')")
done

printf '%s\n' "${items[@]}" | jq -s 'from_entries'
