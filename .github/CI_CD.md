# CI/CD

This repo deploys **only to development**, and **only through GitHub Actions**. There is no `deploy-prod.yml`, no `production` environment, and no local deploy script.

## One-time: GitHub OIDC role

Workflows use `aws-actions/configure-aws-credentials` with `role-to-assume: ${{ secrets.AWS_ROLE_ARN }}`. Create a **dedicated** role for this repo (do not reuse cht-platform-tool or cht-companion unless you extend those trust policies).

### 1. Create the IAM role (AWS admin, once)

Needs `iam:CreateOpenIDConnectProvider`, `iam:CreateRole`, `iam:CreatePolicy` (or updates if they already exist).

```bash
# Optional: resolve numeric IDs used in newer GitHub OIDC `sub` claims
gh api orgs/OasisBureua --jq '.id'
gh api repos/OasisBureua/cht-util-lambdas --jq '.id'

chmod +x infrastructure/aws-github-oidc-setup.sh
./infrastructure/aws-github-oidc-setup.sh
```

The script:

- Ensures the account OIDC provider `token.actions.githubusercontent.com` exists
- Creates/updates IAM role `GitHubActions-CHT-Util-Lambdas`
- Trusts this repo on GitHub environment `development` and `feature/*` (slug + optional immutable org/repo IDs)
- Attaches [infrastructure/iam/github-actions-deploy-policy.json](../infrastructure/iam/github-actions-deploy-policy.json) (ECR `cht-dev-*`, Lambda `cht-dev-*`, Scheduler, Terraform state prefix `util-lambdas/`)

After editing the JSON, push a new policy version **in AWS** (git alone does not update the role):

```bash
./infrastructure/aws-github-oidc-update-deploy-policy.sh
```

That is required when Terraform needs a new ECR/IAM action (for example `ecr:DeleteRepositoryPolicy` when renaming a repo).

### 2. GitHub Environment secret

1. Repo → **Settings → Environments → New environment**
2. Name: **`development`**
3. Add secret:

| Name | Value |
|------|--------|
| `AWS_ROLE_ARN` | `arn:aws:iam::233636046512:role/GitHubActions-CHT-Util-Lambdas` (exact ARN printed by the script) |

Optional: limit the environment to `feature/**` (and `main` if you want manual rollback/lightswitch from main).

### 3. Deploy from Actions

- Push to `feature/**` or **Actions → Deploy to Development → Run workflow**
- First run creates ECR, then images, then functions (chicken-egg handled in `deploy-dev.yml`)
- Manual lightswitch: **Actions → Dev lightswitch** → `on` / `off`

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `pr-validation.yml` | Pull requests | pytest every `lambdas/*/`, Terraform validate |
| `branch-policy.yml` | PRs → `main` | Require head branch `release/*` or `hotfix/*` |
| `security-monthly.yml` | First Monday monthly | Trivy filesystem scan per Lambda |
| `deploy-dev.yml` | Push to `feature/**`, manual | Build/push **changed** Lambda images → `cht-dev-*` ECR; Terraform apply when infra changes |
| `rollback.yml` | Manual | Previous ECR tag → `lambda update-function-code` |
| `dev-lightswitch.yml` | Manual | Invoke `cht-dev-lightswitch-on` or `cht-dev-lightswitch-off` |

## Manual deploy (same as cht-platform-tool)

GitHub only lists **Run workflow** for YAML that exists on **`main`**. After that:

1. **Actions → Deploy to Development → Run workflow**
2. Use branch **`feature/…`** (the branch that has the Lambda/Terraform code)
3. Optional inputs:
   - `deploy_all` — ignore change detection, build every Lambda
   - `plan_only` — Terraform plan, skip apply / image roll

Also available from the same menu once on `main`: **Rollback Deployment**, **Dev lightswitch**.

## Deploy scope

`scripts/ci-detect-changed-lambdas.sh` lists `lambdas/*` that contain a `Dockerfile` and diffs against the change-base SHA:

| Lane | Paths | What runs |
|------|-------|-----------|
| Each Lambda | `lambdas/<name>/**` | Image build/push + `update-function-code` for that name only |
| Infra | `infrastructure/**` | Terraform plan/apply |

Change base:

- **Push:** previous tip (`github.event.before`)
- **Manual run:** last successful run of `deploy-dev.yml` on the same branch
- **Fallback:** merge-base with `origin/main`
- If no base can be resolved, all Lambdas run (safe first deploy)

Manual **Run workflow** has `deploy_all` (default off) to force every Lambda.

| Setting | Value |
|---------|--------|
| AWS region | `us-east-1` |
| ECR registry | `233636046512.dkr.ecr.us-east-1.amazonaws.com` |
| ECR repos | `cht-dev-<lambda-name>` |
| Image tags | `1.0.0`, `1.0.1`, … and `dev-latest` |
| Terraform | `infrastructure/terraform/environments/us-east-1` |
| Var file | `../variables/dev.github.tfvars` |
| Backend | `../backends/us-east-1-dev.hcl` |

## Branch flow

```text
feature/*  →  deploy-dev.yml (development)
       ↓
    main     (PRs from release/* or hotfix/*)
```

`main` is hygiene only — merging it does not deploy a second environment.

## Lightswitch override

Actions → **Dev lightswitch** → `on` or `off`. Source is `github.actions`, which bypasses the US-holiday skip on the `on` Lambda.

## RDS note

A stopped RDS instance may be auto-started by AWS after 7 days. The weekday `off` schedule will stop it again the next evening.
