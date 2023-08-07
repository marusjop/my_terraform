
data "aws_availability_zones" "available" {}

provider "aws" {
  region = "eu-north-1"
}

variable "zmienna" {
    type = string
    description = "A taka moja zmienna"
    default = "domyslna"
}

locals {
  mietek = "miecio"
  nazwi= "bogdan ${var.zmienna}
}



local.mietek