variable "region" {
  default = "eu-south-2"
}
variable "db_username" {
  default = "wordpressuser"
}
variable "db_password" {
  sensitive = true
}
variable "db_name" {
  default = "wordpress"
}
variable "instance_class" {
  default = "db.t3.medium"
}
variable "efs_performance_mode" {
  default = "generalPurpose"
}
variable "efs_throughput_mode" {
  default = "bursting"
}
