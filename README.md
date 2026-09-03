# cht-util-lambdas

This repository is for **util Lambdas only**, and **only for the development environment**.

Utility Lambda functions live here. Application-specific or domain Lambdas belong in their own repositories (`cht-platform-tool`, `cht-companion`, `cht-content-hub`).

There is **no production / platform stack** in this repo. **Deploy only through GitHub Actions** — do not `terraform apply` or push images from a laptop.

## Lambdas

Each function is self-contained under `lambdas/<name>/` (own `Dockerfile`, `requirements.txt`, tests). CI discovers those directories and deploys **only Lambdas whose tree changed**.

| Directory | Function | Schedule |
|-----------|----------|----------|
| `lambdas/dev-lightswitch-on/` | `cht-dev-lightswitch-on` | Weekdays 08:00 America/New_York |
| `lambdas/dev-lightswitch-off/` | `cht-dev-lightswitch-off` | Weekdays 20:00 America/New_York |
| `lambdas/cost-reporter/` | `cht-dev-cost-reporter` | None (stub) |

### Dev lightswitch

Turns **all CHT + Companion + Content Hub dev** compute/databases on during business hours and off overnight, weekends, and US federal holidays.

| Window | State |
|--------|--------|
| Weekdays 08:00–20:00 ET | On (unless a US federal holiday) |
| Weekdays 20:00–08:00 ET | Off |
| Weekends (Fri 20:00 ET → Mon 08:00 ET) | Off |
| US federal holidays (observed) | Off all day (`on` Lambda no-ops) |

Manual GitHub dispatch (`dev-lightswitch.yml`) can turn the env **on** on a holiday or weekend.

**Targets (allowlist):**

| Cluster | Services |
|---------|----------|
| `cht-dev-cluster` | `cht-dev-backend`, `cht-dev-worker`, `cht-dev-companion` |
| `contenthub-dev-cluster` | `contenthub-dev-api` (`contenthub-dev-worker` if present) |

RDS: `cht-dev-db`, `cht-dev-companion-db`, `contenthub-dev-db`. Missing services/DBs are skipped.

**Never touched:** `cht-platform-*`, prod Content Hub (`contenthub-cluster`, `contenthub-api`), `*-prod-*`, or anything without `-dev-` / `Environment=dev|development`.

ALB and NAT stay up. AWS may auto-restart a stopped RDS instance after **7 days**. CloudWatch Logs only (no SNS).

## GitHub OIDC (one-time)

Workflows assume an IAM role via OIDC (`AWS_ROLE_ARN`). No long-lived access keys.

From a machine with AWS admin credentials (IAM create role/policy):

```bash
chmod +x infrastructure/aws-github-oidc-setup.sh
./infrastructure/aws-github-oidc-setup.sh
```

Then in GitHub: **Settings → Environments → `development`** → secret `AWS_ROLE_ARN` = the printed role ARN.

See [.github/CI_CD.md](.github/CI_CD.md) for the full checklist.

## Local tests (not deploy)

```bash
python3 -m venv .venv && source .venv/bin/activate
for d in lambdas/*/; do
  (cd "$d" && pip install -r requirements.txt -r requirements-dev.txt && pytest)
done
```
