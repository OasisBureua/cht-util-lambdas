data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

locals {
  cluster_arns = [
    for cluster in keys(var.ecs_clusters) :
    "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:cluster/${cluster}"
  ]
  service_arns = flatten([
    for cluster, services in var.ecs_clusters : [
      for service in services :
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${cluster}/${service}"
    ]
  ])
  db_arns = [
    for id in var.rds_instance_ids :
    "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:db:${id}"
  ]
  lightswitch_log_arns = [
    for name in var.lightswitch_function_names :
    "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${name}:*"
  ]
  stub_log_arns = [
    for name in var.stub_function_names :
    "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${name}:*"
  ]
}

resource "aws_iam_role" "lightswitch" {
  name               = "cht-dev-lightswitch-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Name        = "cht-dev-lightswitch-lambda"
    Environment = var.environment
    Lightswitch = "true"
  }
}

data "aws_iam_policy_document" "lightswitch" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = local.lightswitch_log_arns
  }

  statement {
    sid = "EcsDescribe"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:ListTagsForResource",
    ]
    resources = concat(local.cluster_arns, local.service_arns, ["*"])
  }

  statement {
    sid       = "EcsUpdate"
    actions   = ["ecs:UpdateService"]
    resources = local.service_arns
  }

  statement {
    sid = "RdsRead"
    actions = [
      "rds:DescribeDBInstances",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "RdsToggle"
    actions = [
      "rds:StartDBInstance",
      "rds:StopDBInstance",
    ]
    resources = local.db_arns
  }
}

resource "aws_iam_role_policy" "lightswitch" {
  name   = "cht-dev-lightswitch-lambda"
  role   = aws_iam_role.lightswitch.id
  policy = data.aws_iam_policy_document.lightswitch.json
}

resource "aws_iam_role" "stub" {
  name               = "cht-dev-util-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Name        = "cht-dev-util-lambda"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "stub" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = length(local.stub_log_arns) > 0 ? local.stub_log_arns : [
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/cht-dev-*:*"
    ]
  }
}

resource "aws_iam_role_policy" "stub" {
  name   = "cht-dev-util-lambda"
  role   = aws_iam_role.stub.id
  policy = data.aws_iam_policy_document.stub.json
}

resource "aws_iam_role" "scheduler" {
  name               = "cht-dev-lightswitch-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json

  tags = {
    Name        = "cht-dev-lightswitch-scheduler"
    Environment = var.environment
    Lightswitch = "true"
  }
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    sid     = "InvokeLightswitch"
    actions = ["lambda:InvokeFunction"]
    resources = [
      for name in var.lightswitch_function_names :
      "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${name}"
    ]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "cht-dev-lightswitch-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}
