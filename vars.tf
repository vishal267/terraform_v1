# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "key_name" {
  default = "play1"
}

variable "network_base_cidr" {
  default = "10.1.0.0/16"
}

variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}

variable "subnet2_address_space" {
  default = "10.1.1.0/24"
}


variable "asg_max_size" {
  default = "1"
}
variable "asg_min_size" {
  default = "1"
}
variable "asg_desired_size" {
  default = "1"
}
variable "ami_id" {
  default = "1"
}
variable "alb_path" {
  default = "/admin"
}
variable "target_group_port" {
  default = "80"
}
variable "certificate_arn" {
  default = "arn"
}
variable "apex_domain" {
  default = "example.one.com"
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 8080
}
