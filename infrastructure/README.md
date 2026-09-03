# Infrastructure

Development-only Terraform for util Lambda **container images**, IAM, EventBridge Scheduler, and CloudWatch logs.

**Apply only from GitHub Actions** (`deploy-dev.yml`). Do not run `terraform apply` locally.

Related: [../README.md](../README.md), [../.github/CI_CD.md](../.github/CI_CD.md).

---

## What Terraform creates

| Module | Resources |
|--------|-----------|
| `modules/ecr` | ECR repos `cht-dev-lightswitch-on`, `cht-dev-lightswitch-off`, `cht-dev-cost-reporter`; scan-on-push; lifecycle (keep 30); `lambda.amazonaws.com` pull policy |
| `modules/iam` | `cht-dev-lightswitch-lambda` (ECS UpdateService + RDS start/stop on allowlisted ARNs only), `cht-dev-util-lambda` (logs), `cht-dev-lightswitch-scheduler` (`lambda:InvokeFunction`) |
| `modules/lambda-image` | Image-based functions + `/aws/lambda/<name>` log groups (7-day retention). **No VPC.** |
| `modules/lightswitch` | Scheduler `cht-dev-lightswitch-on` (08:00 ET Mon–Fri) and `cht-dev-lightswitch-off` (20:00 ET Mon–Fri) + `aws_lambda_permission` |

Composition: [`terraform/environments/us-east-1`](terraform/environments/us-east-1). Always `environment = "dev"`.

This stack does **not** create ECS clusters, RDS, ALBs, or VPCs. It only *controls* existing **dev** CHT / Companion / Content Hub resources via the lightswitch allowlist.

---

## Naming

| Lambda directory | ECR repo / function |
|------------------|---------------------|
| `dev-lightswitch-on` | `cht-dev-lightswitch-on` |
| `dev-lightswitch-off` | `cht-dev-lightswitch-off` |
| `cost-reporter` | `cht-dev-cost-reporter` |

Helper: `./scripts/lambda-aws-name.sh <dir>`.

---

## State and vars

| Item | Value |
|------|--------|
| Backend bucket | `cht-platform-terraform-state` (shared account bucket; name is historical) |
| State key | `util-lambdas/us-east-1-dev/terraform.tfstate` ([`backends/us-east-1-dev.hcl`](terraform/environments/backends/us-east-1-dev.hcl)) |
| Var file (CI) | [`variables/dev.github.tfvars`](terraform/environments/variables/dev.github.tfvars) |
| Region | `us-east-1` |
| Account | `233636046512` |
| Provider | AWS `~> 5.0`, Terraform `>= 1.10.0` |

`dev.github.tfvars` holds the ECS/RDS allowlist, health URLs, and placeholder `lambda_images`. CI overwrites image URIs with `lambda_images.auto.tfvars.json` at plan time.

Default tags: `Project=cht-util-lambdas`, `Environment=dev`, `Region=us-east-1`, `ManagedBy=Terraform`.

---

## Allowlist (lightswitch targets)

From `dev.github.tfvars`, passed into both lightswitch Lambdas and used to scope IAM:

| Cluster | Services |
|---------|----------|
| `cht-dev-cluster` | `cht-dev-backend`, `cht-dev-worker`, `cht-dev-companion` |
| `contenthub-dev-cluster` | `contenthub-dev-api`, `contenthub-dev-worker` |

RDS: `cht-dev-db`, `cht-dev-companion-db`, `contenthub-dev-db`.

---

## GitHub Actions OIDC (one-time)

Workflows use **OIDC** (`AWS_ROLE_ARN`), not long-lived access keys. Run once with AWS admin credentials (creates IAM only — it does not deploy Lambdas):

```bash
./infrastructure/aws-github-oidc-setup.sh
```

| Script | IAM object | GitHub |
|--------|------------|--------|
| `aws-github-oidc-setup.sh` | Role `GitHubActions-CHT-Util-Lambdas` | Environment **`development`** → `AWS_ROLE_ARN` |
| `aws-github-oidc-update-deploy-policy.sh` | Policy `GitHubActions-CHT-Util-Lambdas-Deploy` | after editing [`iam/github-actions-deploy-policy.json`](iam/github-actions-deploy-policy.json) — run this in AWS so CI picks up new actions |

The deploy policy covers ECR `cht-dev-*`, Lambda `cht-dev-*`, Scheduler `cht-dev-lightswitch-*`, and S3 state prefix `util-lambdas/`.

---

## First deploy (GitHub)

`package_type = Image` needs an ECR image before the function can be created. `deploy-dev.yml`:

1. `terraform apply -target=module.ecr` if repos are missing
2. Build/push changed Lambda images
3. Full plan/apply (manual approval) when `infrastructure/**` changed
4. `aws lambda update-function-code` for changed functions

Later image-only deploys skip Terraform unless infra paths changed.

---

## Inspect locally (no apply)

```bash
cd infrastructure/terraform/environments/us-east-1
terraform init -backend-config=../backends/us-east-1-dev.hcl
terraform plan -var-file=../variables/dev.github.tfvars
```

Do not apply from a laptop. Use **Actions → Deploy to Development**.
