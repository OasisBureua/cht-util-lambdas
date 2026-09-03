#!/usr/bin/env bash
# Next semver ECR tag for cht-dev-* images: 1.0.0, 1.0.1, …
# Each segment is 0–9; 4.1.9 → 4.2.0, 4.9.9 → 5.0.0
#
# Usage: ./scripts/next-image-tag.sh [ECR_REPO] [AWS_REGION]
set -euo pipefail

REPO="${1:?repository name required}"
REGION="${2:-us-east-1}"
TAG_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'

if ! command -v aws >/dev/null 2>&1; then
  echo "::error::aws CLI required" >&2
  exit 1
fi

TAGS_FILE="$(mktemp)"
trap 'rm -f "$TAGS_FILE"' EXIT

aws ecr describe-images \
  --repository-name "$REPO" \
  --region "$REGION" \
  --query 'imageDetails[*].imageTags[]' \
  --output text 2>/dev/null \
| tr '\t' '\n' \
| grep -E "$TAG_PATTERN" >> "$TAGS_FILE" || true

if [ ! -s "$TAGS_FILE" ]; then
  echo "1.0.0"
  exit 0
fi

LATEST="$(sort -V "$TAGS_FILE" | uniq | tail -1)"
IFS=. read -r major minor patch <<< "$LATEST"

patch=$((patch + 1))
if [ "$patch" -gt 9 ]; then
  patch=0
  minor=$((minor + 1))
fi
if [ "$minor" -gt 9 ]; then
  minor=0
  major=$((major + 1))
fi

echo "${major}.${minor}.${patch}"
