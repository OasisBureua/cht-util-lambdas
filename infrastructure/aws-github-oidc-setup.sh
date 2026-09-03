#!/usr/bin/env bash
# One-time AWS admin setup: GitHub Actions OIDC role for cht-util-lambdas (development only).
# Does not deploy. Apply/push/invoke happen only in GitHub Actions after you paste the role ARN.
set -euo pipefail

echo "Setting up GitHub Actions OIDC for cht-util-lambdas (development)"
echo "================================================================"
echo ""

DEFAULT_GITHUB_USER="${GITHUB_USER:-OasisBureua}"
DEFAULT_REPO_NAME="${REPO_NAME:-cht-util-lambdas}"
DEFAULT_ORG_ID="${GITHUB_ORG_ID:-248812921}"
DEFAULT_REPO_ID="${GITHUB_REPO_ID:-}"

if [ -t 0 ]; then
  read -r -p "Enter GitHub username or org [${DEFAULT_GITHUB_USER}]: " GITHUB_USER
  GITHUB_USER="${GITHUB_USER:-$DEFAULT_GITHUB_USER}"

  read -r -p "Enter repository name [${DEFAULT_REPO_NAME}]: " REPO_NAME
  REPO_NAME="${REPO_NAME:-$DEFAULT_REPO_NAME}"

  read -r -p "Enter GitHub org ID [${DEFAULT_ORG_ID}]: " GITHUB_ORG_ID
  GITHUB_ORG_ID="${GITHUB_ORG_ID:-$DEFAULT_ORG_ID}"

  echo "Repo numeric ID (optional, recommended). Look it up with:"
  echo "  gh api repos/${GITHUB_USER}/${REPO_NAME} --jq '.id'"
  read -r -p "Enter GitHub repo ID [${DEFAULT_REPO_ID:-skip}]: " GITHUB_REPO_ID
  GITHUB_REPO_ID="${GITHUB_REPO_ID:-$DEFAULT_REPO_ID}"
else
  GITHUB_USER="$DEFAULT_GITHUB_USER"
  REPO_NAME="$DEFAULT_REPO_NAME"
  GITHUB_ORG_ID="$DEFAULT_ORG_ID"
  GITHUB_REPO_ID="$DEFAULT_REPO_ID"
fi

ROLE_NAME="GitHubActions-CHT-Util-Lambdas"
POLICY_NAME="GitHubActions-CHT-Util-Lambdas-Deploy"

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUST_FILE="$(mktemp)"
trap 'rm -f "$TRUST_FILE"' EXIT

SUBS=(
  "repo:${GITHUB_USER}/${REPO_NAME}:environment:development"
  "repo:${GITHUB_USER}/${REPO_NAME}:ref:refs/heads/feature/*"
)
if [ -n "${GITHUB_REPO_ID}" ]; then
  SUBS+=(
    "repo:${GITHUB_USER}@${GITHUB_ORG_ID}/${REPO_NAME}@${GITHUB_REPO_ID}:environment:development"
    "repo:${GITHUB_USER}@${GITHUB_ORG_ID}/${REPO_NAME}@${GITHUB_REPO_ID}:ref:refs/heads/feature/*"
  )
fi

SUBS_JSON="$(printf '%s\n' "${SUBS[@]}" | jq -R . | jq -s .)"

jq -n \
  --arg account "$AWS_ACCOUNT_ID" \
  --argjson subs "$SUBS_JSON" \
  '{
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Principal: {
        Federated: ("arn:aws:iam::" + $account + ":oidc-provider/token.actions.githubusercontent.com")
      },
      Action: "sts:AssumeRoleWithWebIdentity",
      Condition: {
        StringEquals: {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        StringLike: {
          "token.actions.githubusercontent.com:sub": $subs
        }
      }
    }]
  }' > "$TRUST_FILE"

echo ""
echo "Configuration:"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  GitHub repo: $GITHUB_USER/$REPO_NAME"
echo "  GitHub IDs:  org=$GITHUB_ORG_ID repo=${GITHUB_REPO_ID:-<not set>}"
echo "  IAM role:    $ROLE_NAME"
echo "  Trust subs:"
printf '    - %s\n' "${SUBS[@]}"
echo ""

echo "Ensuring GitHub OIDC provider exists..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  2>/dev/null || echo "OIDC provider already exists"

echo "Creating/updating IAM role $ROLE_NAME..."
ROLE_ARN="$(aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "file://${TRUST_FILE}" \
  --description "GitHub Actions deploy role for cht-util-lambdas (development only)" \
  --query 'Role.Arn' \
  --output text 2>/dev/null || \
  aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"

aws iam update-assume-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-document "file://${TRUST_FILE}"

echo "Role: $ROLE_ARN"

echo "Attaching scoped deploy policy..."
POLICY_ARN="$(aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document "file://${SCRIPT_DIR}/iam/github-actions-deploy-policy.json" \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" --query 'Policy.Arn' --output text)"

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN" 2>/dev/null || echo "Policy already attached"

echo ""
echo "Development OIDC setup complete. This script does not deploy anything."
echo ""
echo "In GitHub:"
echo "  1. Settings → Environments → New environment → name: development"
echo "  2. Add environment secret:"
echo "       Name:  AWS_ROLE_ARN"
echo "       Value: ${ROLE_ARN}"
echo ""
echo "Do not reuse cht-platform-tool or cht-companion role ARNs unless you extend those trust policies."
echo "Used by: deploy-dev.yml, rollback.yml, dev-lightswitch.yml"
echo ""
