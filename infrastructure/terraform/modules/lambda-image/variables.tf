variable "function_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "image_uri" {
  type = string
}

variable "timeout_seconds" {
  type    = number
  default = 60
}

variable "memory_mb" {
  type    = number
  default = 128
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "lightswitch" {
  type    = bool
  default = false
}
