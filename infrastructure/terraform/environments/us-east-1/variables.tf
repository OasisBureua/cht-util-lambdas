variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ecs_clusters" {
  description = "Allowlisted dev ECS cluster → service names"
  type        = map(list(string))
}

variable "rds_instance_ids" {
  description = "Allowlisted dev RDS instance identifiers"
  type        = list(string)
}

variable "desired_count_on" {
  type    = number
  default = 1
}

variable "health_urls" {
  type    = list(string)
  default = []
}

variable "lambda_images" {
  description = "Map of lambda directory name → container image URI"
  type        = map(string)
}
