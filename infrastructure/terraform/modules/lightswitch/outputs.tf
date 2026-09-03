output "on_schedule_arn" {
  value = aws_scheduler_schedule.lightswitch_on.arn
}

output "off_schedule_arn" {
  value = aws_scheduler_schedule.lightswitch_off.arn
}
