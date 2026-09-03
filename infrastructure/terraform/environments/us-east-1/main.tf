terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "cht-platform-terraform-state"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    # State key: -backend-config=../backends/us-east-1-dev.hcl
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cht-util-lambdas"
      Environment = var.environment
      Region      = var.aws_region
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  lambdas = {
    dev-lightswitch-on = {
      timeout     = 900
      memory      = 256
      lightswitch = true
    }
    dev-lightswitch-off = {
      timeout     = 900
      memory      = 256
      lightswitch = true
    }
    cost-reporter = {
      timeout     = 60
      memory      = 128
      lightswitch = false
    }
  }

  function_names = {
    for name, _cfg in local.lambdas : name => "cht-dev-${name}"
  }

  repository_names = [
    for name in keys(local.lambdas) : "cht-dev-${name}"
  ]

  lightswitch_env = {
    ALLOWLIST_CLUSTERS = jsonencode(var.ecs_clusters)
    ALLOWLIST_DB_IDS   = jsonencode(var.rds_instance_ids)
    DESIRED_COUNT_ON   = tostring(var.desired_count_on)
    HEALTH_URLS        = join(",", var.health_urls)
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = local.repository_names
  environment      = var.environment
}

module "iam" {
  source = "../../modules/iam"

  environment      = var.environment
  aws_region       = var.aws_region
  aws_account_id   = data.aws_caller_identity.current.account_id
  ecs_clusters     = var.ecs_clusters
  rds_instance_ids = var.rds_instance_ids
  lightswitch_function_names = [
    local.function_names["dev-lightswitch-on"],
    local.function_names["dev-lightswitch-off"],
  ]
  stub_function_names = [
    local.function_names["cost-reporter"],
  ]
}

module "lambda" {
  for_each = local.lambdas
  source   = "../../modules/lambda-image"

  function_name     = local.function_names[each.key]
  environment       = var.environment
  role_arn          = each.value.lightswitch ? module.iam.lightswitch_role_arn : module.iam.stub_role_arn
  image_uri         = var.lambda_images[each.key]
  timeout_seconds   = each.value.timeout
  memory_mb         = each.value.memory
  lightswitch       = each.value.lightswitch
  environment_variables = each.value.lightswitch ? local.lightswitch_env : {
    CHT_ENVIRONMENT = var.environment
  }
}

module "lightswitch" {
  source = "../../modules/lightswitch"

  environment         = var.environment
  on_function_name    = module.lambda["dev-lightswitch-on"].function_name
  on_function_arn     = module.lambda["dev-lightswitch-on"].function_arn
  off_function_name   = module.lambda["dev-lightswitch-off"].function_name
  off_function_arn    = module.lambda["dev-lightswitch-off"].function_arn
  scheduler_role_arn  = module.iam.scheduler_role_arn
}
