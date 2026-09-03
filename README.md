# cht-util-lambdas

**Community Health Technologies — utility Lambdas** for the **development** environment only.

This repo owns scheduled / ops Lambdas (container images). Application Lambdas (chat KB, Content Hub jobs, etc.) stay in their product repos (`cht-platform-tool`, `cht-companion`, `cht-content-hub`).

There is **no production / platform stack** here. **Deploy only through GitHub Actions** — do not `terraform apply` or push images from a laptop.

---

## What it does

| Area | Description |
|------|-------------|
| **Dev lightswitch** | Scale CHT + Companion + Content Hub **dev** ECS services and start/stop their RDS instances on a weekday Eastern schedule |
| **Cost reporter** | Stub for later CUR / Cost Explorer reporting (no schedule) |
| **CI** | Per-Lambda Docker images, change-detected deploy, Terraform for ECR / IAM / Lambda / EventBridge Scheduler |

---

## Project structure

```
cht-util-lambdas/
├── lambdas/
│   ├── dev-lightswitch-on/    # weekday 08:00 ET — scale/start allowlisted dev
│   ├── dev-lightswitch-off/   # weekday 20:00 ET — scale 0 / stop RDS
│   └── cost-reporter/         # stub (no schedule)
├── infrastructure/
│   ├── aws-github-oidc-setup.sh
│   ├── iam/github-actions-deploy-policy.json
│   └── terraform/
│       ├── modules/{ecr,iam,lambda-image,lightswitch}
│       └── environments/us-east-1/   # single env, always dev
├── .github/workflows/         # deploy-dev, rollback, lightswitch, PR checks
└── scripts/                   # image tags, change detection, OIDC helpers
```

Each Lambda is self-contained (`Dockerfile`, `requirements.txt`, tests). CI discovers `lambdas/*/Dockerfile` and deploys **only trees that changed**.

---

## Tech stack

### Lambdas (Python 3.11)

- **AWS Lambda container images** (`public.ecr.aws/lambda/python:3.11`)
- **boto3** — ECS `UpdateService`, RDS `StartDBInstance` / `StopDBInstance`
- **holidays** — US federal holidays on the `on` Lambda only
- **pytest** — unit tests with mocked AWS (no live calls)

### Infrastructure (AWS)

| Resource | Name / notes |
|----------|----------------|
| **ECR** | `cht-dev-lightswitch-on`, `cht-dev-lightswitch-off`, `cht-dev-cost-reporter` (scan on push, Lambda pull policy) |
| **Lambda** | Same names; `package_type = Image`; not in a VPC |
| **IAM** | `cht-dev-lightswitch-lambda` (ECS/RDS allowlist only), `cht-dev-util-lambda` (logs), `cht-dev-lightswitch-scheduler` |
| **EventBridge Scheduler** | `cht-dev-lightswitch-on` (08:00 ET Mon–Fri), `cht-dev-lightswitch-off` (20:00 ET Mon–Fri), timezone `America/New_York` |
| **CloudWatch Logs** | `/aws/lambda/cht-dev-*` (7-day retention) |
| **Terraform** | 1.10.x, AWS provider `~> 5.0` |
| **State** | `s3://cht-platform-terraform-state/util-lambdas/us-east-1-dev/terraform.tfstate` |

Default tags: `Project=cht-util-lambdas`, `Environment=dev`, `ManagedBy=Terraform`, plus `Lightswitch=true` on the on/off functions.

Account `233636046512`, region `us-east-1`.

---

## Lambdas

| Directory | AWS function / ECR | Schedule | Role |
|-----------|--------------------|----------|------|
| `lambdas/dev-lightswitch-on/` | `cht-dev-lightswitch-on` | `cron(0 8 ? * MON-FRI *)` America/New_York | Scale **on** + start RDS. **No-op on US federal holidays** unless invoked from GitHub |
| `lambdas/dev-lightswitch-off/` | `cht-dev-lightswitch-off` | `cron(0 20 ? * MON-FRI *)` America/New_York | desiredCount `0` + stop RDS (including holiday evenings) |
| `lambdas/cost-reporter/` | `cht-dev-cost-reporter` | None | Stub |

Directory `dev-*` maps to AWS name `cht-<dir>` (e.g. `dev-lightswitch-on` → `cht-dev-lightswitch-on`). Other dirs map to `cht-dev-<dir>`.

### Lightswitch schedule

| Window | State |
|--------|--------|
| Weekdays 08:00–20:00 ET | On (unless a US federal holiday) |
| Weekdays 20:00–08:00 ET | Off |
| Weekends (Fri 20:00 ET → Mon 08:00 ET) | Off |
| US federal holidays (observed) | Off all day (`on` Lambda no-ops) |

Manual override: **Actions → Dev lightswitch** → `on` / `off` (`source=github.actions` bypasses the holiday skip).

### Allowlist (what lightswitch may touch)

Configured in [`infrastructure/terraform/environments/variables/dev.github.tfvars`](infrastructure/terraform/environments/variables/dev.github.tfvars) and injected as `ALLOWLIST_CLUSTERS` / `ALLOWLIST_DB_IDS`. IAM is scoped to these ARNs.

**ECS**

| Cluster | Services |
|---------|----------|
| `cht-dev-cluster` | `cht-dev-backend`, `cht-dev-worker`, `cht-dev-companion` |
| `contenthub-dev-cluster` | `contenthub-dev-api`, `contenthub-dev-worker` (skipped if missing) |

**RDS:** `cht-dev-db`, `cht-dev-companion-db`, `contenthub-dev-db`.

Missing services/DBs are skipped. Resources must be tagged `Environment=dev` or `development`.

**Never touched:** `cht-platform-*`, prod Content Hub (`contenthub-cluster`, `contenthub-api`), `*-prod-*`, or names without `-dev-`.

ALB and NAT stay up. AWS may auto-restart a stopped RDS instance after **7 days**. CloudWatch Logs only (no SNS).

Optional health probes (log-only): `https://devapp.communityhealth.media/health/ready`, `https://devhub.communityhealth.media`.

---

## Infrastructure layout

```
infrastructure/terraform/
├── modules/
│   ├── ecr/             # cht-dev-* repos + Lambda pull policy
│   ├── iam/             # lightswitch, stub, and Scheduler roles
│   ├── lambda-image/    # container Lambda + log group
│   └── lightswitch/     # two aws_scheduler_schedule rules
└── environments/
    ├── us-east-1/       # composition (always environment = "dev")
    ├── backends/us-east-1-dev.hcl
    └── variables/dev.github.tfvars
```

Apply **only** from `deploy-dev.yml`. First deploy creates ECR if missing, pushes images, then applies functions + schedules.

Details: [infrastructure/README.md](infrastructure/README.md) and [.github/CI_CD.md](.github/CI_CD.md).

---

## GitHub OIDC (one-time)

Workflows assume `AWS_ROLE_ARN` via OIDC. No long-lived access keys.

```bash
chmod +x infrastructure/aws-github-oidc-setup.sh
./infrastructure/aws-github-oidc-setup.sh
```

Then: **Settings → Environments → `development`** → secret `AWS_ROLE_ARN`.

Creates role `GitHubActions-CHT-Util-Lambdas` and policy `GitHubActions-CHT-Util-Lambdas-Deploy`. Do not reuse the cht-platform-tool or cht-companion role unless you extend those trust policies.

---

## Deploy

| How | What |
|-----|------|
| Push `feature/**` | Auto `deploy-dev.yml` (changed Lambdas / infra only) |
| **Actions → Deploy to Development → Run workflow** | Manual; pick the **feature** branch; optional `deploy_all` / `plan_only` |
| **Actions → Rollback Deployment** | Previous ECR tag → `update-function-code` |
| **Actions → Dev lightswitch** | Invoke on/off now |

`Run workflow` only appears for YAML that exists on **`main`**. Select the feature branch that has the Lambda/Terraform code.

Image tags: `1.0.0`, `1.0.1`, … and `dev-latest`. Registry: `233636046512.dkr.ecr.us-east-1.amazonaws.com`.

```text
feature/*  →  deploy-dev.yml (development)
       ↓
    main     (PRs from release/* or hotfix/*)
```

`main` is hygiene only — it does not deploy a second environment.

---

## Local tests (not deploy)

```bash
python3 -m venv .venv && source .venv/bin/activate
for d in lambdas/*/; do
  (cd "$d" && pip install -r requirements.txt -r requirements-dev.txt && pytest)
done
```
