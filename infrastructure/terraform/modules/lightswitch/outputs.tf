output "on_schedule_arn" {
  value = aws_scheduler_schedule.on.arn
}

output "off_schedule_arn" {
  value = aws_scheduler_schedule.off.arn
}
