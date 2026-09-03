output "lightswitch_role_arn" {
  value = aws_iam_role.lightswitch.arn
}

output "stub_role_arn" {
  value = aws_iam_role.stub.arn
}

output "scheduler_role_arn" {
  value = aws_iam_role.scheduler.arn
}
