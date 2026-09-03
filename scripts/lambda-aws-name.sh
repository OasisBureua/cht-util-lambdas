#!/usr/bin/env bash
# Directory name under lambdas/ → ECR repo / Lambda function name.
#   dev-lightswitch-on  → cht-dev-lightswitch-on
#   cost-reporter       → cht-dev-cost-reporter
set -euo pipefail
name="${1:?lambda directory name required}"
if [[ "$name" == dev-* ]]; then
  echo "cht-${name}"
else
  echo "cht-dev-${name}"
fi
