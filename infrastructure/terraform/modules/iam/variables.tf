variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "lightswitch_function_names" {
  type = list(string)
}

variable "stub_function_names" {
  type = list(string)
}

variable "ecs_clusters" {
  description = "Map of cluster name → service names"
  type        = map(list(string))
}

variable "rds_instance_ids" {
  type = list(string)
}
