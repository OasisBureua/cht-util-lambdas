variable "environment" {
  type = string
}

variable "on_function_name" {
  type = string
}

variable "on_function_arn" {
  type = string
}

variable "off_function_name" {
  type = string
}

variable "off_function_arn" {
  type = string
}

variable "scheduler_role_arn" {
  type = string
}

variable "timezone" {
  type    = string
  default = "America/New_York"
}

variable "on_cron" {
  type    = string
  default = "cron(0 8 ? * MON-FRI *)"
}

variable "off_cron" {
  type    = string
  default = "cron(0 20 ? * MON-FRI *)"
}
