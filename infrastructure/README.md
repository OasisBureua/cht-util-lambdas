# Infrastructure

Development-only Terraform for util Lambda container images, IAM, and EventBridge Scheduler.

**Apply only from GitHub Actions** (`deploy-dev.yml`). Do not run `terraform apply` locally.

- **Env:** `dev`
- **Region:** `us-east-1`
- **State:** `s3://cht-platform-terraform-state/util-lambdas/us-east-1-dev/terraform.tfstate`

## GitHub Actions OIDC (one-time)

Workflows use **OIDC** (`AWS_ROLE_ARN`), not long-lived access keys. Run once from a laptop that already has AWS admin credentials (creates IAM only — it does not deploy Lambdas):

```bash
./infrastructure/aws-github-oidc-setup.sh
```

| Script | IAM role | GitHub secret |
|--------|----------|----------------|
| `aws-github-oidc-setup.sh` | `GitHubActions-CHT-Util-Lambdas` | Environment **`development`** → `AWS_ROLE_ARN` |
| `aws-github-oidc-update-deploy-policy.sh` | updates `GitHubActions-CHT-Util-Lambdas-Deploy` | after editing `iam/github-actions-deploy-policy.json` |

Then: GitHub → **Settings → Environments → `development`** → add `AWS_ROLE_ARN`.

Full steps: [.github/CI_CD.md](../.github/CI_CD.md).
