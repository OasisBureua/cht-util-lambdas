resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.function_name}-logs"
    Environment = var.environment
    Lightswitch = var.lightswitch ? "true" : "false"
  }
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = var.role_arn
  package_type  = "Image"
  image_uri     = var.image_uri
  timeout       = var.timeout_seconds
  memory_size   = var.memory_mb

  environment {
    variables = var.environment_variables
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  tags = {
    Name        = var.function_name
    Environment = var.environment
    Service     = var.function_name
    Lightswitch = var.lightswitch ? "true" : "false"
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
