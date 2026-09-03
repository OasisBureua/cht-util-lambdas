variable "repository_names" {
  description = "ECR repository names to create"
  type        = list(string)
}

variable "environment" {
  type = string
}

variable "log_retention_images" {
  description = "Keep this many tagged images"
  type        = number
  default     = 30
}
