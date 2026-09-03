#!/usr/bin/env bash
# Discover lambdas/*/Dockerfile and emit which ones changed.
#
# Usage: ci-detect-changed-lambdas.sh <force_all> [base_sha]
# Writes lambdas_json / has_lambdas / deploy_infra to GITHUB_OUTPUT.
set -euo pipefail

FORCE_ALL="${1:-false}"
BASE_SHA="${2:-}"
HEAD_SHA="${GITHUB_SHA:-HEAD}"

list_lambdas() {
  shopt -s nullglob
  for dockerfile in lambdas/*/Dockerfile; do
    basename "$(dirname "$dockerfile")"
  done | sort
}

mapfile -t ALL_LAMBDAS < <(list_lambdas)

CHANGED=()
if [ "$FORCE_ALL" = "true" ] || [ -z "$BASE_SHA" ]; then
  CHANGED=("${ALL_LAMBDAS[@]}")
else
  while IFS= read -r file; do
    case "$file" in
      lambdas/*/*)
        name="${file#lambdas/}"
        name="${name%%/*}"
        if [ -f "lambdas/${name}/Dockerfile" ]; then
          CHANGED+=("$name")
        fi
        ;;
    esac
  done < <(git diff --name-only "$BASE_SHA" "$HEAD_SHA")
  if [ ${#CHANGED[@]} -gt 0 ]; then
    mapfile -t CHANGED < <(printf '%s\n' "${CHANGED[@]}" | sort -u)
  fi
fi

DEPLOY_INFRA=false
if [ "$FORCE_ALL" = "true" ] || [ -z "$BASE_SHA" ]; then
  DEPLOY_INFRA=true
elif git diff --name-only "$BASE_SHA" "$HEAD_SHA" | grep -q '^infrastructure/'; then
  DEPLOY_INFRA=true
fi

if [ ${#CHANGED[@]} -eq 0 ]; then
  JSON='[]'
  HAS=false
else
  JSON="$(printf '%s\n' "${CHANGED[@]}" | jq -R . | jq -s -c .)"
  HAS=true
fi

{
  echo "lambdas_json=${JSON}"
  echo "has_lambdas=${HAS}"
  echo "deploy_infra=${DEPLOY_INFRA}"
} >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT not set}"

echo "Deploy scope: lambdas=${JSON} infra=${DEPLOY_INFRA} force_all=${FORCE_ALL}"
