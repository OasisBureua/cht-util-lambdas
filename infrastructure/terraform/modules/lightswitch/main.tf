resource "aws_scheduler_schedule" "lightswitch_on" {
  name                         = "cht-dev-lightswitch-on"
  description                  = "Weekday 08:00 ET — scale CHT/Content Hub/Companion dev on"
  schedule_expression          = var.on_cron
  schedule_expression_timezone = var.timezone
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = var.on_function_arn
    role_arn = var.scheduler_role_arn
    input = jsonencode({
      source = "eventbridge.scheduler"
    })
  }
}

resource "aws_scheduler_schedule" "lightswitch_off" {
  name                         = "cht-dev-lightswitch-off"
  description                  = "Weekday 20:00 ET — scale CHT/Content Hub/Companion dev off"
  schedule_expression          = var.off_cron
  schedule_expression_timezone = var.timezone
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = var.off_function_arn
    role_arn = var.scheduler_role_arn
    input = jsonencode({
      source = "eventbridge.scheduler"
    })
  }
}

resource "aws_lambda_permission" "on_scheduler" {
  statement_id  = "AllowEventBridgeSchedulerOn"
  action        = "lambda:InvokeFunction"
  function_name = var.on_function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.on.arn
}

resource "aws_lambda_permission" "off_scheduler" {
  statement_id  = "AllowEventBridgeSchedulerOff"
  action        = "lambda:InvokeFunction"
  function_name = var.off_function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.off.arn
}
