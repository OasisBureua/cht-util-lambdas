# Non-secret infra for GitHub Actions deploy-dev.yml (committed).

environment = "dev"
aws_region  = "us-east-1"

ecs_clusters = {
  cht-dev-cluster = [
    "cht-dev-backend",
    "cht-dev-worker",
    "cht-dev-companion",
  ]
  contenthub-dev-cluster = [
    "contenthub-dev-api",
    "contenthub-dev-worker",
  ]
}

rds_instance_ids = [
  "cht-dev-db",
  "cht-dev-companion-db",
  "contenthub-dev-db",
]

desired_count_on = 1

health_urls = [
  "https://devapp.communityhealth.media/health/ready",
  "https://devhub.communityhealth.media",
]

# Overridden per deploy when images are built. Placeholders for first plan.
lambda_images = {
  dev-lightswitch-on  = "233636046512.dkr.ecr.us-east-1.amazonaws.com/cht-dev-lightswitch-on:dev-latest"
  dev-lightswitch-off = "233636046512.dkr.ecr.us-east-1.amazonaws.com/cht-dev-lightswitch-off:dev-latest"
  cost-reporter       = "233636046512.dkr.ecr.us-east-1.amazonaws.com/cht-dev-cost-reporter:dev-latest"
}
