#!/usr/bin/env bash
# Build a JSON object {lambda_images: {name: uri, ...}} for terraform -var-file.
# Uses newly built tags from images.env (NAME=tag lines) when present,
# otherwise the live Lambda ImageUri, otherwise :dev-latest.
#
# Usage: ci-lambda-image-map.sh <ecr_registry> <aws_region> [images.env]
# Always writes JSON to stdout. Safe to run from any cwd.
set -euo pipefail

REGISTRY="${1:?registry required}"
REGION="${2:-us-east-1}"
IMAGES_ENV="${3:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

tag_for() {
  local name="$1"
  if [ -n "$IMAGES_ENV" ] && [ -f "$IMAGES_ENV" ]; then
    awk -F= -v n="$name" '$1==n {print $2; exit}' "$IMAGES_ENV"
  fi
}

items=()
shopt -s nullglob
for dockerfile in "$ROOT"/lambdas/*/Dockerfile; do
  name="$(basename "$(dirname "$dockerfile")")"
  repo="$("$ROOT/scripts/lambda-aws-name.sh" "$name")"
  fn="$repo"
  tag="$(tag_for "$name")"
  if [ -n "$tag" ]; then
    uri="${REGISTRY}/${repo}:${tag}"
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

if [ ${#items[@]} -eq 0 ]; then
  echo "No lambdas/*/Dockerfile found under ${ROOT}" >&2
  exit 1
fi

printf '%s\n' "${items[@]}" | jq -s '{lambda_images: from_entries}'
