#!/usr/bin/env bash
# Push a new default version of the GitHub Actions deploy policy (after editing the JSON).
set -euo pipefail
export AWS_PAGER=""

POLICY_NAME="GitHubActions-CHT-Util-Lambdas-Deploy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Resolving AWS account..."
AWS_ACCOUNT_ID="$(aws --no-cli-pager sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
echo "Account ${AWS_ACCOUNT_ID}"
echo "Updating IAM policy ${POLICY_NAME}..."

# IAM allows at most 5 versions. Drop the oldest non-default if we are at the cap.
VERSION_COUNT="$(aws --no-cli-pager iam list-policy-versions \
  --policy-arn "$POLICY_ARN" \
  --query 'length(Versions)' \
  --output text)"
if [ "${VERSION_COUNT}" -ge 5 ]; then
  OLD_VERSION="$(aws --no-cli-pager iam list-policy-versions \
    --policy-arn "$POLICY_ARN" \
    --query 'Versions[?IsDefaultVersion==`false`] | sort_by(@, &CreateDate)[0].VersionId' \
    --output text)"
  echo "Deleting oldest non-default version ${OLD_VERSION} (5-version limit)..."
  aws --no-cli-pager iam delete-policy-version \
    --policy-arn "$POLICY_ARN" \
    --version-id "$OLD_VERSION"
fi

aws --no-cli-pager iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document "file://${SCRIPT_DIR}/iam/github-actions-deploy-policy.json" \
  --set-as-default \
  --output table

echo "Policy updated. Re-run Deploy to Development from GitHub."
