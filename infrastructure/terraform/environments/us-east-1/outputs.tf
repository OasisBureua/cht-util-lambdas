output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "lambda_function_names" {
  value = { for name, fn in module.lambda : name => fn.function_name }
}

output "lambda_function_arns" {
  value = { for name, fn in module.lambda : name => fn.function_arn }
}

output "lightswitch_on_schedule_arn" {
  value = module.lightswitch.on_schedule_arn
}

output "lightswitch_off_schedule_arn" {
  value = module.lightswitch.off_schedule_arn
}
