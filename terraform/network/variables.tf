variable "vpc_name" {
    type = string
}
variable "environment" {
    type = string
  
}
variable "cidr" {
    type = string
  
}
variable "aws_azs" {
    type = list(string)
  
}
variable "public_cidr" {
    type = list(string)
  
}
variable "private_cidr" {
    type = list(string)
  
}