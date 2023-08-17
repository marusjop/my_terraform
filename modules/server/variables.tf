variable "ami" {}
variable "size" {
  default = "t3.micro"
}
variable "subnet_id" {}
variable "vpc_security_group_ids" {
  type = list(any)
}
