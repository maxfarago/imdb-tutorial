variable "region" {
  type        = string
  description = "The region in which to deploy"
}

variable "az1" {
  type        = string
  description = "To assign desired AZ"
}

variable "az2" {
  type        = string
  description = "To assign desired AZ"
}

variable "instance_type" {
  type        = string
  description = "Assign an instance type"
}

variable "ami" {
  type        = string
  description = "ami to use for instances"
}

variable "key_pair" {
  type        = string
  description = "The access key to use for programmatic access to instances"
}

variable "dbpw" {
  type        = string
  description = "RDS Master Password"
}

variable "hosted_zone" {
  type        = string
  description = "The existing domain name to use for web servers"
}

variable "new_sub_domain" {
  type        = string
  description = "Domain for the ACM certificate"
}

variable "lb_log_bucket" {
  type        = string
  description = "Name for the log bucket"
}
